use 5.006;
use inc::Module::Install;
 
# Define metadata
name           'Emails-Parser';
perl_version   '5.006';
license 		'perl';
all_from       'lib/Emails/Parser.pm';
 
# Specific dependencies
requires 		'App::Options' => 0;
requires		'Carp' => '1.26';
requires		'Class::MOP' => '2.0402';
requires		'Data::Dumper' => 0;
requires		'DateTime' => '0.72';
requires		'DBI' => '1.616';
requires		'DBD::mysql' => '0';
requires		'Email::Address' => 0;
requires		'HTML::FormatText' => 0;
requires		'HTML::TreeBuilder' => '4.2';
requires		'Mail::Address' => '2.08';
requires		'Mail::Header' => '2.08';
requires		'Mail::Internet' => '2.08';
requires		'Mail::Mailer' => '2.08';
requires		'Mail::Message::Convert' => 0;
requires		'Mail::Thread' => 0;
requires		'Mail::Thread::Chronological' => 0;
requires		'Mail::Util' => '2.08';
requires		'Moose' => '0.11';
requires		'Smart::Comments' => 0;
requires		'Term::ProgressBar::Simple' => 0;
requires		'Term::ProgressBar::Quiet' => 0;
requires		'Text::Autoformat' => 0;
requires		'Text::Markdown' => 0;

test_requires  'Test::More'  => '0.42';

WriteAll;
