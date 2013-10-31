# -*- python -*-

# Copyright (C) 1998,1999,2000,2001,2002 by the Free Software Foundation, Inc.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software 
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

"""This module contains your site-specific settings.

From a brand new distribution it should be copied to mm_cfg.py.  If you
already have an mm_cfg.py, be careful to add in only the new settings you
want.  Mailman's installation procedure will never overwrite your mm_cfg.py
file.

The complete set of distributed defaults, with documentation, are in the file
Defaults.py.  In mm_cfg.py, override only those you want to change, after the

  from Defaults import *

line (see below).

Note that these are just default settings; many can be overridden via the
administrator and user interfaces on a per-list or per-user basis.

"""

###############################################
# Here's where we get the distributed defaults.

from Defaults import *
import pwd, grp

##################################################
# Put YOUR site-specific settings below this line.

##############################################################
#    Here's where we override shipped defaults with settings #
#    suitable for the RPM package.                           #
MAILMAN_UID = pwd.getpwnam('mailman')[2]
MAILMAN_GID = grp.getgrnam('mailman')[2]

##############################################################
#    Set URL and email domain names                          #
# 
# Mailman needs to know about (at least) two fully-qualified domain
# names (fqdn)
#
# 1) the hostname used in your urls (DEFAULT_URL_HOST)
# 2) the hostname used in email addresses for your domain (DEFAULT_EMAIL_HOST)
#
# For example, if people visit your Mailman system with
# "http://www.dom.ain/mailman" then your url fqdn is "www.dom.ain",
# and if people send mail to your system via "yourlist@dom.ain" then
# your email fqdn is "dom.ain".  DEFAULT_URL_HOST controls the former,
# and DEFAULT_EMAIL_HOST controls the latter.  Mailman also needs to
# know how to map from one to the other (this is especially important
# if you're running with virtual domains).  You use
# "add_virtualhost(urlfqdn, emailfqdn)" to add new mappings.

# Default to using the FQDN of machine mailman is running on.
# If this is not correct for your installation delete the following 5
# lines that acquire the FQDN and manually edit the hosts instead.

from socket import *
try:
    fqdn = getfqdn()
except:
    fqdn = 'mm_cfg_has_unknown_host_domains'


fqdn = 'fully-qualified.domain.com'
DEFAULT_URL_HOST   = 'url-to-visit.com'
DEFAULT_EMAIL_HOST = 'default.email-host.com'

# Because we've overriden the virtual hosts above add_virtualhost
# MUST be called after they have been defined.

add_virtualhost(DEFAULT_URL_HOST, DEFAULT_EMAIL_HOST)

# Use non-crappy passwords
MEMBER_PASSWORD_LENGTH = 12
USER_FRIENDLY_PASSWORDS = True

##############################################################
# Put YOUR site-specific configuration below, in mm_cfg.py . #
# See Defaults.py for explanations of the values.	     #

# Note - if you're looking for something that is imported from mm_cfg, but you
# didn't find it above, it's probably in Defaults.py.

MTA = 'Postfix'

# Enable VERP by default.  Your site may not require VERP; this may slow down very
# large mailing lists, but I consider it polite.

VERP_PROBES = Yes
VERP_PASSWORD_REMINDERS = Yes
VERP_PERSONALIZED_DELIVERIES = Yes
VERP_DELIVERY_INTERVAL = 1
VERP_CONFIRMATIONS = Yes
OWNERS_CAN_ENABLE_PERSONALIZATION = Yes

# jwb Added for MySQL integration

MYSQL_MEMBER_DB_NAME = "vanilla"
MYSQL_MEMBER_DB_USER = "vanilla"
MYSQL_MEMBER_DB_PASS = "vanilla"
MYSQL_MEMBER_DB_HOST = "localhost"
MYSQL_MEMBER_TABLE_TYPE = "flat"
MYSQL_MEMBER_TABLE_NAME = "GDN_mailman_mysql"

# This will cause the table to be created the first time the MySQL member adaptor is activated.
MYSQL_MEMBER_CREATE_TABLE = True

MYSQL_MEMBER_DB_VERBOSE = True


# Bitfield for user options.  See DEFAULT_NEW_MEMBER_OPTIONS above to set
# defaults for all new lists.
# Digests             = 0 # handled by other mechanism, doesn't need a flag.
# DisableDelivery     = 1 # Obsolete; use set/getDeliveryStatus()
# DontReceiveOwnPosts = 2 # Non-digesters only
# AcknowledgePosts    = 4
# DisableMime         = 8 # Digesters only
# ConcealSubscription = 16
# SuppressPasswordReminder = 32
# ReceiveNonmatchingTopics = 64
# Moderator = 128
# DontReceiveDuplicates = 256

DEFAULT_NEW_MEMBER_OPTIONS = 32

# Make it so you can edit messages on the local file system before sending them out
HOLD_MESSAGES_AS_PICKLES = No