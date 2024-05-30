#!/usr/bin/perl

# Sample Perl client accessing JIRA via SOAP using the CPAN
# JIRA::Client module. This is mostly a translation of the Python
# client example at
# http://confluence.atlassian.com/display/JIRA/Creating+a+SOAP+Client.

#use strict;
use warnings;
use Data::Dumper;
use DateTime;
#use JIRA::Client;
use XMLRPC::Lite;
use SOAP::Lite;
use Term::ReadKey;
use Config::Simple;
use Getopt::Long;
use JIRA::REST;
use JSON qw( decode_json );
use Text::Tabs;
use Encode;
use Try::Tiny;
use Config::Identity;

#my %identity = Config::Identity::PAUSE->load_check;

#read in config file
$cfg = new Config::Simple('prettylogs.conf');
$jirauser = $cfg->param('JIRAUser');
$passwd = $cfg->param('JIRAPW');



print "\n";
print "\n";

@outputarray = ("Changelogs ");
@sortedArray = (" ");
@finalOutput = (" ");
$beginningtag = "";
$endtag = "";

Getopt::Long::GetOptions(
   'bt=s' => \$beginningtag,
   'et=s' => \$endtag,
   'o=s' => \$outputfile,
   'html=s' => \$html,
   'out=s' => \$outputfile,
   'sort' => \$sortoption,
   'repo=s' => \$otherrepo,
   'h' => \$help);


if ($otherrepo)
{
	$repo = $otherrepo
}
else 
{
	$repo = $cfg->param('REPO');
}   
   
if ($beginningtag eq "" || $endtag eq "")
{
	if ($help)
	{	printUsage(); }
	
	else
	{
		print "your beginning tag and end tags are empty \n";
		printUsage();
	}
}
   
else
{
	print "Github Changelog Generator\n";
	print "\n";
	
	@changelog = `cd $repo && git log --oneline --max-parents=1  --pretty=format:\"%h, %s\" $beginningtag...$endtag  | cut -d \" \" -f 2-`;
	chomp @changelog;
	printLogs();
}


sub printUsage{
	print "Usage: perl prettyLogs.pl -bt <val> -et <val> [output options] \n";
	print "\n \n \n";
	print "  -bt      This is the beginning tag to be used. \n";  
	print "           It should be the most recent tag you want to use. \n";
	print "  -et      This is the ending tag. \n";  
	print "           It should be the tag you want the logs to go back to. \n";
	print "  -o       Name of your output file.  Example: outputfile.txt \n";
	print "  -sort    Output is sorted.  The intermediate tags will not be displayed. \n";
	print "  -repo    Specify a repository other than the one listed in the conf file. \n";
	print "  -html    Outputs in html format.  Two files are generated.\n";
	print "           1st file is htmoutname.htm.out  This file is for use on the portal. \n";
	print "           2nd file is htmoutname.html  This file is for use to open in a browser. \n";
}

#primary subroutine for processing the changelogs
sub printLogs{
 
	foreach my $line (@changelog)
	{
	  
	  $line =~ /(?{s{"}{\"}g;})/;
	  $line =~ s/[^!-~\s]//g;
          $line = expand($line); #expand all tabs.
	  
	  my @splitstring = split /\s+/,$line, 2; 
	  	  
	  $extractedjira = substr( $line, 0, index( $line, ' ' ) );; 
	  $summary = $splitstring[1];
	  #print "OG jira is $extractedjira ";
	  
	  #trim whitespaces on both ends and newline
	  $extractedjira =~ s/^\s+|\s+$//g;  
	  
	  $extractedjira =~ s/\\n//g;  
	  #$extractedjira =~ s/[\$#@~!&*()\[\];.,:?^ `\\\/]+//g;
	  $extractedjira =~ s/[[:^alnum:]]/-/g; #cleaning the jira here;
	  
	  #print "printing precleaned jira $extractedjira \n";
	  
	  if ($extractedjira !~ m/(IDE|EPE|HH|HPCC|HD|HSIC|JAPI|JDBC|ML|ODBC|RH|WSSQL)/ ) 
	  #IDE|EPE|HH|HPCC|HD|HSIC|JAPI|JDBC|ML|ODBC|RH|WSSQL
	  #if ($extractedjira eq "Community"|| $extractedjira eq "Split" || $extractedjira eq "Signed-off-by" || $extractedjira eq "Merge" || $extractedjira eq "Fix" )  
	   {
		 #extracted jira isn't really a jira.  It's either a tag or some other split action in git
		 #don't print splits of branch
		 if ($extractedjira eq "Community")
			 {   
			    $printline = " ".$line." ";
				#print $printline;
				#push(@workingarray, $printline);
			    push(@outputarray, $printline);
			 }
		else
		 { 
			if ($extractedjira !~ m/(Merge|Split|Signed-off-by)/)
			{
				#$printline = " $line \n";
				#$printline = "                                    | $extractedjira maybe $summary";
				#print "$printline";
				$printline = "                                    | $line ";
				push(@outputarray, $printline);
				push(@workingarray, $printline);
			}
		 } 
	   }

	  else {
	   
	   #call jira cleaner subscript.
	   $extractedjira = jiraCleaner(uc $extractedjira);
	   
	   #print "making sure this is the cleaned JIRA $extractedjira \n";
	   
	   if ($extractedjira eq "HPCC-")
	   {
		
		$printline = " ".$line." ";
		#print $printline;
		#push(@workingarray, $printline);
		push(@outputarray, $printline);
	
	   }
	 
	   else
	   {
	   $currentComponent = getComponent($extractedjira);
	   #$currentComponent =~ tr/ //ds;
	   #$currentComponent =~ tr/ //ds;
	   if (defined $currentComponent)
		 { 
				
			  $tempprintline = "$extractedjira $summary";
			  $printline = sprintf("%-35s | %-60s ",$currentComponent,$tempprintline);			  
			  #$printline = "$tempprintline $summary";
			  push(@outputarray, $printline);
			  push(@workingarray, $printline);
			
		 }
		}
	   }	  
	}
	
}

sub dedupe {
    my %hash;
    $hash{$_}++ for @_;
  return keys %hash;
}


sub sortedOut
{
	
	my $str = "|";             # |
	my $re = quotemeta($str);  # \|

    @workingarray = dedupe(@workingarray);	
	
	my @tempsort = sort { (split $re, $a)[0].(split $re, $a)[1] cmp (split $re, $b)[0].(split $re, $b)[1]} @workingarray;

	
	push(@sortedArray, "Sorted Changelogs ");
	push(@sortedArray, "Beginning Tag: $beginningtag ");
	push(@sortedArray, "End Tag:       $endtag ");
    push(@sortedArray, " ");
	
	foreach (@tempsort) 
	{
		push(@sortedArray, $_);
	}
	

	
}

outputToAll();
sub outputToAll
{
	#print @outputarray;
	
	if($sortoption)
	{
		sortedOut();
		@finalOutput=@sortedArray;
			
	}
	else
	{
		@finalOutput=@outputarray;
	}
	foreach (@finalOutput) 
	{
		print "$_\n";
	}
	
	#create output file.  
	if($outputfile)
	{ 
	   	open($myout, '>', $outputfile) or die;
		print $myout @finalOutput;
		close $myout;
	}
	
 	
	
	if($html)
	{
		#close FILE;
		#first file is for portal
		#second file is for emails

		
		$tmphtml = $html . "\.tmp";
		open($tempout, '>', $tmphtml) or die;
		
		foreach (@finalOutput) 
		{
			print $tempout "$_\n";
		}
		#print $tempout @finalOutput;
		close $tempout;
		
		
		$htmout = $html . "\.htm\.out";
		open($myhtmout, '>', $htmout) or die;
		close $myhtmout;
		
		$sysout = "cat $tmphtml  | sed -E 's=(IDE|EPE|HH|HPCC|HD|HSIC|JAPI|JDBC|ML|ODBC|RH|WSSQL)(-[0-9]+)=\\\<a\\ href\\\=\\\"https://hpccsystems.atlassian.net/\\1\\2\\\"\\\ target\\\=\\\"_blank\"\\\>\\1\\2\\</a\\\>=g' > $htmout";
		
		system($sysout);
		
		$htmlfile = $html . "\.html";
		`cp '$htmout' '$htmlfile'`;
		
				
		open my $in,  '<',  $htmout      or die "Can't read old file: $!";
		open my $out, '>', $htmlfile or die "Can't write new file: $!";

		print $out "<pre>\n"; # <--- HERE'S THE MAGIC

		while( <$in> )
			{
			print $out $_;
			}
		
		close $out;
		open(my $fd, '>>', $htmlfile);
		print $fd "</pre>";
		close $fd;
		
		system("rm $tmphtml");
	}
	
	
}

sub jiraCleaner{

	my ($precleanjira) = @_;
	my $jiratype;
	my $precleannumber;
	my $cleanednumber;
	my $cleanedjira;
   my $precleanclone;
	 
	#$precleanjira = decode_utf8( $precleanjira);
	#$precleanjira =~ s/[[:^alnum:]]//g;
	
	#$jiratype = $precleanjira;
	#$cleanednumber = $precleanjira;
	
	#$precleanjira =~ s/:/-/g;
	
	#print " strip the hyphen or colon jira $precleanjira ";
	
	($jiratype, $cleanednumber) = $precleanjira =~/([a-zA-Z]+)(\d+)/;;

		
	($jiratype, $precleannumber) = split /[[:^alnum:]]/, $precleanjira;
	( $cleanednumber = ($precleannumber // '') ) =~ s/\D+//g;
	
	
	#$cleanednumber =~ s/\D+//g;
	$cleanedjira = $jiratype . "-" . $cleanednumber;
	

	#$cleanedjira = $precleanjira =~ s/([a-zA-Z]+)([0-9]+)/\1-\2/g;
	
	return $cleanedjira;
}


#subroutine for getting the component from jira.  

sub getComponent{
	local ($issuenumber) = uc $_[0];
    my $jira = JIRA::REST->new('https://hpccsystems.atlassian.net', $jirauser, $passwd);
	
    my $finalcomponentname;
	#my $issue = $jira->GET("/issue/$issuenumber");
	try {
		my $issue = $jira->GET("/issue/$issuenumber");
		} catch {
		$finalcomponentname = " ";
		} finally { 
		my $issue = $jira->GET("/issue/$issuenumber");
			
	
			foreach my $componentname (@{$issue->{fields}->{components}}) 
			{
				if (!defined $finalcomponentname)
				{$finalcomponentname = $componentname->{name};}
				else {$finalcomponentname = $finalcomponentname . ", " . $componentname->{name};};
			}
		};
	
	


	if(!defined $finalcomponentname)
	{
		$finalcomponentname = " ";
		
	}
	return $finalcomponentname;
	
}



