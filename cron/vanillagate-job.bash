#!/usr/bin/env bash
source ~/.bashrc
/usr/bin/perl /home/vanillagate/Emails-Parser/parse-emails.pl
/usr/bin/php -q /var/www/html/plugins/UsefulFunctions/bin/tick.php
