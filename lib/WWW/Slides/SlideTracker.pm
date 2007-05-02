package WWW::Slides::SlideTracker;
{
   use version; our $VERSION = qv('0.0.3');

   use warnings;
   use strict;
   use Carp;

   use Object::InsideOut;

   # Module implementation here
   my @slide_show : Field    # Where we're getting the slides from
     : Std(Name => 'slide_show', Private => 1)
     : Get(Name => 'slide_show', Private => 1)
     : Arg(Name => 'slide_show', Mandatory => 1);
   my @current : Field       # Main slide for talk
     : Std(Name => 'current') : Arg(Name => 'current')
     : Get(Name => 'current');
   my @served_slides : Field    # Track already-sent slides
     : Std(Name => 'served_slides', Private => 1);

   sub _init : Init {
      my $self = shift;
      $self->set_served_slides({});
      $self->goto($self->slide_show()->id_first())
         unless defined $self->current();
      return;
   }

   sub already_served_current {
      my $self = shift;
      return exists $self->get_served_slides()->{$self->current()};
   }

   sub current_still_unserved {
      my $self = shift;
      return !($self->already_served_current());
   }

   sub mark_current {
      my $self = shift;
      $self->get_served_slides()->{$self->current()} = 1;
      return;
   }

   sub goto {
      my $self = shift;
      my ($slide_no) = @_;
      return unless $self->slide_show()->validate_slide_id($slide_no);
      $self->set_current($slide_no);
      return;
   }

   sub get_next {
      my $self = shift;
      return $self->slide_show()->id_next($self->current());
   }

   sub goto_next {
      my $self = shift;
      $self->goto($self->get_next());
      return;
   }

   sub get_previous {
      my $self = shift;
      return $self->slide_show()->id_previous($self->current());
   }

   sub goto_previous {
      my $self = shift;
      $self->goto($self->get_previous());
      return;
   }

   sub get_first {
      my $self = shift;
      return $self->slide_show()->id_first();
   }

   sub goto_first {
      my $self = shift;
      $self->goto($self->get_first());
      return;
   }

   sub get_last {
      my $self = shift;
      return $self->slide_show()->id_last();
   }

   sub goto_last {
      my $self = shift;
      $self->goto($self->get_last());
      return;
   }
}

1;    # Magic true value required at end of module
__END__

=head1 NAME

WWW::Slides::SlideTracker - track transitions around a slide show.


=head1 VERSION

This document describes WWW::Slides::SlideTracker version 0.0.3


=head1 SYNOPSIS

    use WWW::Slides::SlideTracker;

    my $tracker = WWW::Slides::SlideTracker->new(
      slide_show => $slide_show,  # e.g. WWW::Slides::SlideShow
      current    => 2,            # starting slide
    );

    my $current_id = $tracker->current();
    my $current_id = $tracker->get_current(); # alias
    $tracker->goto(3);

    my $next_id = $tracker->get_next();
    $tracker->goto_next();

    my $previous_id = $tracker->get_next();
    $tracker->goto_previous();

    my $first_id = $tracker->get_next();
    $tracker->goto_first();

    my $last_id = $tracker->get_next();
    $tracker->goto_last();

    $tracker->mark_current();    # set current slide as marked
    print 'unserved' if $tracker->current_still_unserved();
    print 'served' if $tracker->already_served_current();
    
  
=head1 DESCRIPTION

This module is generally not meant for usage outside WWW::Slides::Talk
or WWW::Slides::Attendee. Changes without notice are possible albeit
not much probable.

Slides can be marked for later reference. This is useful, for example,
to track which slides have been already sent to a given Attendee, in order
to avoid re-sending of the slide's data (which could also make a mess
putting two divs with the same id-s).

The method names are pretty self-explanatory.


=head1 INTERFACE 

There are four main groups of methods:

=over

=item

constructor;

=item

slide marking management;

=item

slide transition peeking;

=item

slide transition actuation.

=back


=head2 Constructor

The constructor method is named C<new> and accepts the following arguments:

=over

=item B<slide_show> (mandatory)

any WWW::Slides::SlideShow interface compliant object.

=item B<current> (optional)

the slide where the tracker should be set first. Defaults to the slide
id given back as B<id_first()> from the C<slide_show> object described
above.

=back


=head2 Slide Marking Management

This group can handle a mark for each slide, setting the mark and retrieving
the mark status. Note that at the moment there is no way to un-mark a slide.

There are three methods in this area:

=over

=item B<mark_current()>

Set a mark on the current slide.

=item B<already_served_current()>

True if there is a mark on the current slide, false otherwise.

=item B<current_still_unserved()>

True if the current slide has no mark, false otherwise. This is the
exact negation of C<already_served_current()>, just syntactic sugar.

=back


=head2 Slide Transition Peeking

These methods allow to I<peek> which slide would be set after a given
transition. These are also the functions internally used by the
L<Slide Transition Actuation> functions decribed in the next paragraph.

There are five methods in this area:

=over

=item B<current()> or B<get_current()>

=item B<get_first()>

=item B<get_last()>

=item B<get_previous()>

=item B<get_next()>

=back

Names are sufficiently self-explanatory. Note that I<previous> and I<next> 
are intended with respect to the current slide.


=head2 Slide Transition Actuation

These methods allow the tracker to make a transition to a given slide.
Note that a transition does B<NOT> mean that the slide will be marked,
you have to call the marking methods explicitly.

These are the methods in this area:

=over

=item B<goto($slide_no)>

Goto the given C<$slide_no>. Consistency check will be on for this method
(as opposed to C<set_current()>, see below), for this reason this is
the suggested method to use.

=item B<set_current($slide_no)>

Goto the given C<$slide_no>. No consistency check will be done for this.
Use C<goto()>, it's more robust.

=item B<goto_first()>

=item B<goto_last()>

=item B<goto_previous()>

=item B<goto_next()>

=back

Names are sufficiently self-explanatory. Note that I<previous> and I<next> 
are intended with respect to the current slide.



=head1 DIAGNOSTICS

Shouldn't balk at you.


=head1 CONFIGURATION AND ENVIRONMENT
  
WWW::Slides::SlideTracker requires no configuration files or environment 
variables.


=head1 DEPENDENCIES

Object::InsideOut.


=head1 INCOMPATIBILITIES

None reported.


=head1 BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests through http://rt.cpan.org/


=head1 AUTHOR

Flavio Poletti  C<< <flavio [at] polettix [dot] it> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2007, Flavio Poletti C<< <flavio [at] polettix [dot] it> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>
and L<perlgpl>.

Questo modulo è software libero: potete ridistribuirlo e/o
modificarlo negli stessi termini di Perl stesso. Vedete anche
L<perlartistic> e L<perlgpl>.


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.

=head1 NEGAZIONE DELLA GARANZIA

Poiché questo software viene dato con una licenza gratuita, non
c'è alcuna garanzia associata ad esso, ai fini e per quanto permesso
dalle leggi applicabili. A meno di quanto possa essere specificato
altrove, il proprietario e detentore del copyright fornisce questo
software "così com'è" senza garanzia di alcun tipo, sia essa espressa
o implicita, includendo fra l'altro (senza però limitarsi a questo)
eventuali garanzie implicite di commerciabilità e adeguatezza per
uno scopo particolare. L'intero rischio riguardo alla qualità ed
alle prestazioni di questo software rimane a voi. Se il software
dovesse dimostrarsi difettoso, vi assumete tutte le responsabilità
ed i costi per tutti i necessari servizi, riparazioni o correzioni.

In nessun caso, a meno che ciò non sia richiesto dalle leggi vigenti
o sia regolato da un accordo scritto, alcuno dei detentori del diritto
di copyright, o qualunque altra parte che possa modificare, o redistribuire
questo software così come consentito dalla licenza di cui sopra, potrà
essere considerato responsabile nei vostri confronti per danni, ivi
inclusi danni generali, speciali, incidentali o conseguenziali, derivanti
dall'utilizzo o dall'incapacità di utilizzo di questo software. Ciò
include, a puro titolo di esempio e senza limitarsi ad essi, la perdita
di dati, l'alterazione involontaria o indesiderata di dati, le perdite
sostenute da voi o da terze parti o un fallimento del software ad
operare con un qualsivoglia altro software. Tale negazione di garanzia
rimane in essere anche se i dententori del copyright, o qualsiasi altra
parte, è stata avvisata della possibilità di tali danneggiamenti.

Se decidete di utilizzare questo software, lo fate a vostro rischio
e pericolo. Se pensate che i termini di questa negazione di garanzia
non si confacciano alle vostre esigenze, o al vostro modo di
considerare un software, o ancora al modo in cui avete sempre trattato
software di terze parti, non usatelo. Se lo usate, accettate espressamente
questa negazione di garanzia e la piena responsabilità per qualsiasi
tipo di danno, di qualsiasi natura, possa derivarne.

=cut
