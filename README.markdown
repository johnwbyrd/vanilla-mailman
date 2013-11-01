<link href="http://kevinburke.bitbucket.org/markdowncss/markdown.css" rel="stylesheet"></link>
# vanilla-mailman 

---

## Caveat emptor

*If you don't understand anything else in this document, read this:* This 
software can only be installed and made operational by an engineer who
understands perl, PHP, MySQL and editing configuration files by hand.
This is not a piece of software that you can slam in and let 'er rip.
There are simply too many moving parts.  Patience and some testing
time will be necessary to make sure that all these parts interrelate
and work correctly with one another.  Moreover, I just don't have a ton
of time to support this software.

# About this software

This is a set of scripts and logic for integrating the 
open-source version of [Vanilla Forum](http://www.vanillaforums.org) 
with the GNU version of [Mailman version 
2.1](http://www.gnu.org/software/mailman/).  It allows _bi-directional
discussions_ between e-mail and an online discussion forum.  Users may
talk with each other transparently via either the Vanilla web interface 
or via a mailman listserver.

The latest version of this documentation is available at 
(http://johnwbyrd.github.io/vanilla-mailman/).
The current version of the software is available from 
(https://github.com/johnwbyrd/vanilla-mailman) .
Comments and advice on how this software may be improved are very 
welcome; I encourage pull requests and other patches to improve 
stability and compatibility.

# Features 

- Full bi-directional support for discussions and comments emanating 
from users participating via the Vanilla web forum interface or via 
Mailman's web email interface. Users may converse with one another via 
e-mail list or the Web interface, and the discussion is seamless to all 
parties. 
- Smart message reformatting. Messages from Vanilla are reformatted 
intelligently into text and HTML format emails. Message quoting and 
reformatting is automatically detected and converted into HTML when 
email is sent from Mailman into Vanilla. 
- Smart thread recovery and reconstruction. The software is able to 
figure out threading via e-mail discussions and appropriately 
reconstruct threads within Vanilla's comments structure, using the JWZ 
algorithm. 
- Integrated password management. Users may change Mailman list 
properties entirely from within Vanilla, including setting no-mail, 
digest, HTML versus plain text emails, and receive own mailing flags. 
Additionally, changing the password for a user within Vanilla updates 
the corresponding password within Mailman. 
- Free (and worth every penny).

# Installation requirements 

Integrating a web-based discussion forum with an email list is a 
non-trivial task with many corner cases. Therefore this software has 
some strong opinions on how this integration should be accomplished. 

First, the versions of Mailman as well as Vanilla are highly specific. 
Mailman must be of the 2.1+ variety, with the modifications described 
herein; the new 3.0 branch is currently guaranteed not to work with this 
implementation, because this implementation accesses MySQL databases in 
which both Mailman and Vanilla store their details directly. 

This system was designed to run on a single CentOS 6.4 installation with 
command-line and root access. Later versions of CentOS 6.x might work, 
but the installation steps may vary from the steps described in 
this document. In this installation, the Vanilla Forum, as well as the 
mailman server, are intended to run on the same physical machine; 
however there is no techical reason why this must be the case, as long 
as the shared MySQL database is accessible to both the server running 
Vanilla as well as the server running Mailman. However, a dual-server 
installation has not been tested. 

# Installation

There are several major steps that must be completed in the following
order to get this software to work correctly.

- Install CentOS prerequisites
	- gcc
	- wget
	- mysql-devel
	- httpd
	- OPTIONAL: epel
	- OPTIONAL: phpMyAdmin
	- perl
	- CPAN
	- cpanm
- Uninstall sendmail
- Install and test postfix
- Download and compile mailman
- Install mailman
- Test mailman
- OPTIONAL: Set up SPF
- OPTIONAL: Set up DKIM
- Install vanilla forum
- Install necessary vanilla plugins 
	- Force Guest Sign-In
	- Useful Functions
	- Mailman
- Install Emails-Parser 
- Set up gateway user (vanillagate)
	- Install cron jobs for vanillagate
- OPTIONAL: install xdebug

# Install CentOS prerequisites

This installation was conducted on CentOS 6.4 Final, with:

	# yum upgrade
	
run on it as of August 23 2013.

First, install EPEL.  Generic instructions on how to set up EPEL are [here.](http://fedoraproject.org/wiki/EPEL/FAQ#How_can_I_install_the_packages_from_the_EPEL_software_repository.3F)

At this point, install several prerequisites at once:
	
	# yum install gcc make httpd mysql-devel perl-CPAN php-mysql php53-string php-cli mysql-server python-devel MySQL-python
	
and accept all prerequisites to be installed.

At this point you need to set (if you haven't already) a MySQL root 
password. Generic instructions on how to do this are 
[here.](http://dev.mysql.com/doc/refman/5.0/en/resetting-permissions.html) 
However, I found it easiest to do this by running the script that was 
automatically installed at: 

	# /usr/bin/mysql_secure_installation
	
This script allows you to set a root password for MySQL.

MySQL seems to want to open a port 3306 when it is installed; this is 
likely not what you want. To disable this, add this to the end of 
/etc/my.cnf: 

	# Stop permitting access from any IP address
	[mysqld]
	bind-address=127.0.0.1

Make sure the services start at boot time as well:

	# chkconfig mysqld on
	# chkconfig httpd on

## Install EPEL and phpMyAdmin

This step is recommended but not strictly necessary. If you don't do this though you'll 
need to have another preferred method for viewing and administrating the 
MySQL database you just installed. Generic instructions on how to set up 
EPEL are [here.](http://fedoraproject.org/wiki/EPEL/FAQ#How_can_I_install_the_packages_from_the_EPEL_software_repository.3F)

Once you've done this, you can type

	# yum install phpMyAdmin
	
to install phpMyAdmin.

The default installation of phpMyAdmin via EPEL is extremely 
restrictive. You may wish to edit /etc/httpd/conf.d/phpMyAdmin.conf so 
that your IP address is permitted to access it remotely: 

	<IfModule !mod_authz_core.c>
		# Apache 2.2
		Order Deny,Allow
		Deny from All
		Allow from 127.0.0.1
		Allow from your.ip.address.here
		Allow from ::1
	</IfModule>
   
Furthermore, the default httpd.conf file limits the ability of the .htaccess file
which was part of Vanilla to do prettier URLs.  To fix this and restore
pretty URLs, look in the section of /etc/httpd/conf/httpd.conf that starts with
<Directory "/var/www/html"> and modify the AllowOverride directive from None
to All:

	AllowOverride All

Once you've edited that file, restart httpd:

	service httpd restart
	
### Optional: install mutt

This software reads and parses e-mail using the Maildir directory 
format. One mail client that reads and writes this format, and hence is 
useful for debugging, is the mutt mail reader. 

	# yum install mutt
	
After installing mutt, you can read and view email for any particular 
user more easily by setting up either a user-specific .muttrc file or a 
system-wide /etc/Muttrc file with contents something like the following: 

	set mbox_type = Maildir
	set spoolfile = "~/Maildir"
	set folder = '~/Maildir' # default: '~/Mail'
	set from = 'this.user@yourmailserver.com' # default: ''
	set visual = 'nano' # default: ''
	
## Remove sendmail and install postfix

	# yum erase sendmail
	# yum install postfix
	
At this point, you'll need to edit the default postfix settings in 
/etc/postfix/main.cf . Sanity check all the settings in this file, but 
in particular to get this working with Mailman you'll also need to set 
the *myhostname* setting in main.cf to be the publicly available 
hostname of your server: 

	myhostname = your.hostname.com
	
Also, the people who wrote this distribution thought it was a good idea 
that it should not actually send and receive mail from the Internet, so 
you have to change this default: 

	inet_interfaces = all
	
Uncomment the recipient_delimiter line, which Mailman uses to handle bounces:

	recipient_delimiter = +
	
This system uses Maildir style mailboxes to hold traffic to and from the 
forum, so uncomment the Maildir home_mailbox option: 

	home_mailbox = Maildir/
	
# Install mailman

*IMPORTANT!* Do *NOT* use yum to install mailman. It's necessary to 
change a lot of the default settings from the way that the CentOS 
distribution does this by default. So download the latest Mailman 2.1 
sources from the GNU distribution: 

	# cd ~
	# wget http://ftp.gnu.org/gnu/mailman/mailman-2.1.16rc2.tgz
	# tar xfvz mailman-2.1.16rc2.tgz
	# cd mailman-2.1.16rc2
	# useradd -c "Mailman" -s /sbin/nologin -U mailman
	# chmod a+rx,g+ws /var/lib/mailman
	# ./configure --with-cgi-gid=apache --with-mail-gid=mailman --with-var-prefix=/var/lib/mailman --with-mailhost=your.mailhost.com --with-urlhost=your.mailmanurl.com
	# make
	# make install
	
Enable an administrative mailing list:

	# cd /usr/local/mailman/bin
	# ./newlist mailman
	# ./config_list -i /usr/local/mailman/data/sitelist.cfg
	
## Teach httpd to display mailman scripts
	
Teach httpd that it should use the Mailman scripts to display web pages. 
Copy the mailman.conf file from the Mailman-2.1 changes directory to the 
/etc/httpd/conf.d directory, or use it as a guide to set up your own 
mailman.conf file on the server. 

## Set up mm_cfg.py

Copy mm_cfg.py from the mailman-2.1 changes directory to 
/usr/local/mailman/Mailman on the remote server. This file will need to 
be edited to set the fully qualified domain name of the server and email 
hosts: 

	fqdn = 'your.mailman.com'
	DEFAULT_URL_HOST   = 'your.mailman.com'
	DEFAULT_EMAIL_HOST = 'your.mailman.com'

	# Because we've overriden the virtual hosts above add_virtualhost
	# MUST be called after they have been defined.

	add_virtualhost(DEFAULT_URL_HOST, DEFAULT_EMAIL_HOST)

## Set up aliases for postfix

In /etc/postfix/main.cf, tweak the alias_maps line:

	alias_maps = hash:/etc/aliases, hash:/var/lib/mailman/data/aliases
	
## Copy magic files into Mailman install

For each mailing list that you create, you'll need to copy the extend.py 
file from the Mailman-2.1 changes folder in the distribution into each 
subdirectory that exists within /var/lib/mailman/lists/ that you want to 
share with the online web forum. This extend.py file tells Mailman to 
use the MySQL adapter to list the users that will be present in that 
particular mailing list. 

Additionally, copy the MySqlMemberships.py file from the Mailman-2.1 
changes folder into the /usr/local/mailman/Mailman directory. This is 
the MySQL adapter file that causes Mailman to read from the MySQL 
database instead of a Python pickle for getting the user list. 

Once you've done these things you'll need to restart Mailman to use these
new files:

	# /usr/local/bin/mailman/bin/mailmanctl restart
	
At this point, if you have correctly set everything up, there should be 
a new table in the database called GDN_mailman_mysql which contains names
for each of the mailman users.

Note: on my installation I had to enable all permissions globally for
/root/.python-eggs in order to proceed.  Another way of getting the same 
result would be to edit extend.py with the following information:

	import os
	os.environ['PYTHON_EGG_CACHE']='/path/to/egg/cache'

## Finish mailman installation

At this point, you'll have to do the remaining manual steps for 
installing Mailman, including [installing the 
crontab](http://www.gnu.org/software/mailman/mailman-install/node41.html) as well as [installing and starting the default 
service.](http://www.gnu.org/software/mailman/mailman-install/node42.html) Also, you'll need to [create site and list 
passwords.](http://www.gnu.org/software/mailman/mailman-install/node44.html) 

Make sure that you can log in and administrate your mailing list via the 
Mailman web interface at the http://your.site.com/mailman address. Also, 
now would be a good time to verify that mail coming into and out of your 
mailing list works normally as well. 

## Install your own mailing list(s)

At this point, you'll need to teach Mailman about any mailing lists that 
you want Mailman to manage. Create your mailing lists in the usual 
fashion using the Mailman web interface.  See <http://www.gnu.org/software/mailman/mailman-install/node45.html> 
for more details.  Also verify that your mailing lists operate nominally
as mailing lists before proceeding.

# Set up anti-spam protection for your list

While it is not strictly necessary to set up anti-spam features for your mailing list,
the vast majority of modern mail services will immediately mark your mail as spam
unless you install some modern services on your postfix mail server.  These include
at least SPF, DKIM and possibly DMARC.

## Set up SPF

While setting up an SPF record for your domain is beyond the scope of this document,
some general advice is in order.  If you are running your own mail server, as this 
document assumes, then you will need to add a TXT record with the (short) host name
of your mail server, and a TXT record with a value like

	v=spf1 mx -all
	
For more information on how to design an SPF record, see <http://www.openspf.org/Tools>
and/or <http://www.microsoft.com/mscorp/safety/content/technologies/senderid/wizard/>
and/or <http://www.kitterman.com/spf/validate.html>.

## Set up DKIM

As root, install the OpenDKIM package:
	
	# yum install opendkim
	
Restart the opendkim daemon:

	# service opendkim restart
	
This in turn will automatically generate 1024-bit keys for you:

	Stopping OpenDKIM Milter:                                  [FAILED]
	Generating default DKIM keys:                              [  OK  ]
	Default DKIM keys for yourserver.com created in /etc/opendkim/keys.
	Starting OpenDKIM Milter:                                  [  OK  ]
	
Now edit /etc/opendkim.conf.  Set the operating mode to s (signer):

	Mode  s
	
And set the domain you're signing for, i.e. the domain of the mail server:

	Domain  your.mailserver.com
	
Add the following line (if necessary) to permit signing from any subdomains
within your domain:

	Subdomains yes
	
Uncomment the InternalHosts file location:

	InternalHosts   refile:/etc/opendkim/TrustedHosts
	
At this point, you will need to edit the /etc/opendkim/TrustedHosts
file and add your local host information to the file:

	127.0.0.1
	localhost
	localhost.localdomain
	your.mailserver.com
	
Next, edit /etc/postfix/main.cf and add the following information, which queries
the local OpenDKIM server from within postfix:

	smtpd_milters = inet:127.0.0.1:8891
	non_smtpd_milters = $smtpd_milters
	milter_default_action = accept
	milter_protocol = 2
	
Restart opendkim and then restart postfix:

	# service opendkim restart
	# service postfix restart
	
## Create a DMARC record for your domain

The best tool I've found for designing a DMARC record for your domain is
at <http://www.unlocktheinbox.com/dmarcwizard/>.  Again you'll need
to modify your TXT records for your domain in question.

## Set up reverse DNS for your mail server

Many modern e-mail services will reject your e-mail just for not having
reverse DNS set up appropriately.  Make sure that reverse DNS is working
correctly for your domain.

Once you have done all this, e-mail sent from your postfix mail server
to a mail testing service, such as that at <http://www.mail-tester.com/>,
should indicate that your e-mail is spam-free.

# Install Vanilla forum

Install the 2.2.3.5 version of Vanilla into the /var/www/html directory 
on the server. Later or other versions may or may not work with the 
Vanilla plugin for Mailman. You'll need to set up a Vanilla-specific 
user on MySQL in order to do this; I found phpMyAdmin very helpful, but 
it's also possible via the command line as well. 

## Optional: install xdebug

This step may be skipped if everything works the way you expect, but if 
for some reason the Mailman plugin misbehaves, installing xdebug on the 
web server can be used to help debug the plugin. If you've installed 
EPEL, you can at this point install xdebug in a straightforward manner: 
	
	yum install php-pecl-xdebug
	
Now xdebug.so lives in /usr/lib64/php/modules/xdebug.so .

At this point you will need to tweak xdebug for your installation, via editing /etc/php.d/xdebug.ini:

	; Enable xdebug extension module
	zend_extension=/usr/lib64/php/modules/xdebug.so
	xdebug.remote_enable=On
	; xdebug.remote_autostart=On
	xdebug.remote_handler=dbgp
	; developer workstation IP address
	xdebug.remote_host=1.2.3.4
	xdebug.remote_port=9000
	xdebug.remote_mode=req
	
Then restart the web server:

	# service httpd restart
	
Debugging a PHP installation is beyond the scope of this document, but I used Eclipse
and SFTP to develop and debug the Vanilla plugin.  

## Install necessary Vanilla plugins

The following plugins must be installed into Vanilla for this system to work:

	Logger
	UsefulFunctions
	
To install these plugins, download them from 
http://www.vanillaforums.org and copy the directories into the 
/var/www/html/plugins directory on the server. Case is important -- make 
sure the directories are capitalized. Additionally, copy the Mailman 
folder onto the server, also into /var/www/html/plugins . 

The following plugin may optionally be installed:

	ForceGuestSignIn

Note that there is as of this writing a bug in the ForceGuestSignIn 
plugin that causes the plugin not to work correctly. In default.php, 
find the line labelled 

	header('location:/entry')
	
and replace it with 

	Redirect('entry');

and your plugin would work with configurations that are installed not in 
the root. 

## Install the Mailman plugin

Copy the Mailman directory provided in this system to the Vanilla 
plugins directory at /var/www/html/plugins . Then log on to Vanilla as 
the Vanilla administrator and go to the Vanilla dashboard. Under the 
Addons tab, select Plugins. You should see an entry for the Mailman 
plugin. Enable this plugin. Then, click the Settings button for the 
Mailman plugin. 

The only setting that must be edited in this screen for the default 
install, is the List Email Address. This should be the e-mail address 
that a normal user would send e-mail to have it republished by mailman. 
Edit this field accordingly and click Save. 

# Integrate Vanilla's and mailman's user databases

Now that you've installed Vanilla and mailman, you can get them talking 
to one another.  The first step to doing this is to make sure users
can authenticate against the mailman database of users.

## Create a mailman user that can access the Vanilla database

Using the phpMyAdmin interface at http://yourserver.com/phpMyAdmin in
order to create a user named mailman.  Assign this user a secure password.
Grant database specific privileges to the mailman user so that the user
can make any changes to the vanilla database.  (If you've chosen a
different name for the default Vanilla database you'll need to assign
them accordingly here.)

## Tweak mm_cfg.py settings to permit access from mailman into MySQL

Check and modify the MySQL settings in 
/usr/local/mailman/Mailman/mm_cfg.py. You've edited this file before but 
you'll need to do it again for this phase: 

	MYSQL_MEMBER_DB_NAME = "vanilla"
	MYSQL_MEMBER_DB_USER = "mailman"
	MYSQL_MEMBER_DB_PASS = "YourSecurePassword"
	MYSQL_MEMBER_DB_HOST = "localhost"
	MYSQL_MEMBER_TABLE_TYPE = "flat"
	MYSQL_MEMBER_TABLE_NAME = "GDN_mailman_mysql"
	
Change these fields according to your particular installation; at least 
you will need to change the password to be the one you chose in the 
previous step. 

At this point you should be able to log into Vanilla as any user you
create for a mailman mailing list.  Verify that you can change
user settings such as mail delivery within a user's profile and see
these changes occurring in the corresponding MySQL database before
proceeding.

# Gate email from the mailman into Vanilla

For each mailing list, you're going to first create a gateway user 
account that can read and write the MySQL database. Then, you'll add the 
gateway user account to the mailman mailing list so that mail sent 
through the list will arrive at the user account.  Lastly you'll set
up a cron job so that the mailman plugin's tick function is called
regularly, and incoming e-mail is parsed and sent to Vanilla regularly.

## Create a MySQL user that has access to the Vanilla database

Using phpMyAdmin, create a MySQL user with the name vanillagate and 
a secure password.  Grant all privileges to the vanillagate MySQL 
user to the vanilla database.

## Create a gateway user account 

	# useradd vanillagate
	# passwd vanillagate
	(set a different secure password here)
	
At this point if you haven't done so login as the vanillagate user to 
continue configuring the parser.  All this installation will be done as
the vanillagate user, to avoid installing a ton of CPAN modules as root.
	
## Download and install the local-lib bootstrapper

Download and install the latest tarball from 
<http://search.cpan.org/~ether/local-lib/lib/local/lib.pm> .  
These instructions were interpolated from 
<http://search.cpan.org/~ether/local-lib/lib/local/lib.pm> :

	$ wget http://search.cpan.org/CPAN/authors/id/E/ET/ETHER/local-lib-1.008018.tar.gz
	$ tar xfz local-lib*
	$ cd local-lib-1.008018
	$ perl Makefile.PL --bootstrap
	$ make test && make install
	$ echo 'eval $(perl -I$HOME/perl5/lib/perl5 -Mlocal::lib)' >>~/.bashrc
	$ source ~/.bashrc
	$ cd ..
	
## Tell CPAN to automatically install all dependencies

	$ perl -MCPAN -e shell

Run these two commands in the CPAN shell:

	o conf prerequisites_policy follow
	o conf commit

Now, exit the CPAN shell with Ctrl-D.
	
## Install cpanminus

	$ curl -L http://cpanmin.us | perl - App::cpanminus
	
## Install the Emails-Parser perl framework

Copy the Module/Emails-Parser directory to the vanillagate user's 
account.  The perl module should exist at /home/vanillagate/Emails-Parser
after completion.

	$ cd ~vanillagate/Emails-Parser
	$ ls 
	inc  lib  Makefile.PL  MANIFEST  parse-emails.conf  parse-emails.pl
	$ chown -R vanillagate.vanillagate *

Now you're ready to install Emails-Parser:

	$ cpanm .
	
This will take a while.  After this is concluded you should be able 
to run the parsing email script:

	$ cd ~
	$ perl Emails-Parser/parse-emails.pl

You will get an error about being unable to connect to the database.
Edit the file Emails-Parser/parse-emails.conf:

	dbhost = localhost
	dbname = vanilla
	dbuser = vanillagate
	dbpass = thesecuremysqlpassword
	mailboxtype = maildir
	mailfolder = /home/vanillagate/Maildir
	maillistname = yourmailinglistname
	dbtrace = 0
	
Edit each of the fields in parse-emails.conf accordingly.  At this
point, running the parse-emails.pl perl script should connect to the 
database:

	WARNING: Folder does not exist, failed opening maildir folder /home/vanillagate/Maildir.
	
You may optionally set dbtrace to [a number described in the DBI.pm perl 
module](http://search.cpan.org/~timb/DBI/DBI.pm#TRACING) to detect and 
debug database connection issues, if necessary; set it back to 0 when 
you're done. 

## Add the vanillagate user to the mailman mailing list
	
At this point you're ready to add the vanillagate user to the mailman
mailing list, and try sending a test message to the vanillagate 
user.

Log in to the mailman administrative interface at 
http://yourmailmanserver.com/mailman/admin/yourmaillist name, click on 
Membership Management, click on Mass Subscription, and add the full 
vanillagate@yourmailserver.com address to be subscribed to the mailing 
list. 

## Set up tick and parsing jobs for vanillagate user

First, make sure you're logged onto an account that can edit permissions 
of files in the Vanilla web directory. 

In order to run the Vanilla tick job, the tick program needs to be able 
to write to the directory plugins/UsefulFunctions/bin . Yes this is a 
silly and unnecessary security hole. Just do it and don't think about it 
too much. 

	cd /var/www/html
	cd plugins/UsefulFunctions
	chmod 777 bin
	
Log on as the vanillagate user. Run the following commands at the shell 
prompt as the vanillagate user: 

	/usr/bin/perl /home/vanillagate/Emails-Parser/parse-emails.pl
	
That command should produce only a single line of output:

	Pushing messages to forum: 100% [====================================]D 0h00m00s
	
Next, run the following command:

	/usr/bin/php -q /var/www/html/plugins/UsefulFunctions/bin/tick.php
	
There should be no error messages appearing. If error messages appear in 
either of those outputs, figure out why before proceeding; error 
messages appearing in either command will cause a series of exciting 
cascading errors when you go to the next step. 

## Install cron jobs for vanillagate

Copy the vanillagate-job.bash file from the cron directory from this 
package into the root directory of the vanillagate user, at 
/home/vanillagate. You may review the contents of this file if you wish. 

Set the permissions correctly on the file:

	chmod 755 vanillagate-job.bash

Set your favorite text editor via the command prompt first:

	export EDITOR=nano
	
Next, edit the crontab file for the vanillagate user:

	crontab -e
	
When the editor appears, add the following lines:

	*/5 * * * * /home/vanillagate/vanillagate-job.bash
	
Since you're editing a crontab, you can adjust the first digit in each 
line to describe how frequently these jobs should be run. I'm running 
them every 5 minutes here. 

Your installation of php may require the date.timezone setting to be
set in order to satiate the strtotime() function.  Edit /etc/php.ini,
and find the date.timezone setting, and set it to one of the values
you find in (http://www.php.net/manual/en/timezones.php) :

	date.timezone = America/Los_Angeles

If all goes well, you should be in business now. Try gating some e-mails 
back and forth from the Web interface to the mailing list, and vice 
versa. 

## Optional: Disable logging in as the vanillagate user

For extra security, you may now set the vanillagate's user shell to 
/sbin/nologin if you wish by editing /etc/passwd as the root user.

# License agreement

vanilla-mailman, Copyright (C) 2013  John Byrd

 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/> .



