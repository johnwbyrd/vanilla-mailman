# import the MySQL stuff
from Mailman.MysqlMemberships import MysqlMemberships

# override the default for this list
def extend(mlist):
	mlist._memberadaptor = MysqlMemberships(mlist)
