use strict;
use warnings;
use Test::More tests => 30;
use Test::Exception;
use Test::MockObject;

my $module = 'WWW::Slides::SlideTracker';
require_ok($module);

my $slide_show = Test::MockObject->new();
$slide_show->mock(id_first    => sub { return 0 });
$slide_show->mock(id_last     => sub { return 5 });
$slide_show->mock(id_next     => sub { return $_[1] + 1 });
$slide_show->mock(id_previous => sub { return $_[1] - 1 });
$slide_show->set_true('validate_slide_id');

my $tracker;
lives_ok {
   $tracker =
     $module->new(
      {slide_show => $slide_show, current => $slide_show->id_first()});
  }
  'constructor ok with all mandatory parameters';

#### First slide
is($tracker->current(), 0, 'starting good');
ok($tracker->current_still_unserved(), 'start slide unmarked');
ok(! $tracker->already_served_current(), 'start slide unmarked (neg test)');

$tracker->mark_current();
ok(! $tracker->current_still_unserved(), 'slide marked (neg test)');
ok($tracker->already_served_current(), 'slide marked');


#### Advance to next
$tracker->goto_next();
is($tracker->current(), 1, 'goto_next transition');
ok($tracker->current_still_unserved(), 'slide still unmarked');
ok(! $tracker->already_served_current(), 'slide still unmarked (neg test)');

$tracker->mark_current();
ok(! $tracker->current_still_unserved(), 'slide marked (neg test)');
ok($tracker->already_served_current(), 'slide marked');


#### Goto last
$tracker->goto_last();
is($tracker->current(), 5, 'goto_last transition');
ok($tracker->current_still_unserved(), 'slide still unmarked');
ok(! $tracker->already_served_current(), 'slide still unmarked (neg test)');

$tracker->mark_current();
ok(! $tracker->current_still_unserved(), 'slide marked (neg test)');
ok($tracker->already_served_current(), 'slide marked');


#### Step back to previous
$tracker->goto_previous();
is($tracker->current(), 4, 'goto_previous transition');
ok($tracker->current_still_unserved(), 'slide still unmarked');
ok(! $tracker->already_served_current(), 'slide still unmarked (neg test)');

$tracker->mark_current();
ok(! $tracker->current_still_unserved(), 'slide marked (neg test)');
ok($tracker->already_served_current(), 'slide marked');


#### Back to first, which should be still marked
$tracker->goto_first();
is($tracker->current(), 0, 'goto_last transition');
ok(! $tracker->current_still_unserved(), 'slide marked (neg test)');
ok($tracker->already_served_current(), 'slide marked');


#### Peek methods
$tracker->goto(1);
is($tracker->current(), 1, 'absolute goto 1');
is($tracker->get_previous(), 0, 'get_previous');
is($tracker->get_next(), 2, 'get_next');
is($tracker->get_last(), 5, 'get_last');
is($tracker->get_first(), 0, 'get_last');
