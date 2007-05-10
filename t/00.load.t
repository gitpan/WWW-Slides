use strict;
use warnings;
use Test::More tests => 13;

BEGIN {
   diag('Testing inclusions');
   for my $module ( 'WWW::Slides',
      map { "WWW::Slides::$_" }
      qw( Talk Attendee SlideShow SlideTracker BasicLogger
      Controller::UDP Controller::TCP Controller::STDIO
      Controller::Multiple Controller::Single
      Client::TCP Client::Base
      )
     )
   {
      use_ok($module);
      no strict 'refs';
      diag("Loading $module ${$module . '::VERSION'}");
   } ## end for my $module (map { "WWW::Slides::$_"...
} ## end BEGIN
