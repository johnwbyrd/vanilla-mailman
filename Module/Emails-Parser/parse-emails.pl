#!/usr/bin/perl

use strict;

use Emails::Parser;
use Data::Dumper;
 
my $parser = Emails::Parser->new;

$parser->parse();

1;
