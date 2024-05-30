#!/bin/bash

sudo cpan App::cpanminus --force
sudo cpanm DateTime --force
sudo cpanm App::Gitc::Its::Jira --force
sudo cpanm XMLRPC::Lite --force
sudo cpanm Term::ReadKey --force
sudo cpanm Config::Simple --force
sudo cpanm JIRA::REST --force
sudo cpanm Date::PeriodParser --force
sudo cpanm Config::Identity --force

echo "Done"
echo "Now Run: perl PrettyLogs.pl"
