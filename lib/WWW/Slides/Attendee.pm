package WWW::Slides::Attendee;
{
   use version; our $VERSION = qv('0.0.4');

   use warnings;
   use strict;
   use Carp;

   use Object::InsideOut;
   use IO::Handle;
   use HTTP::Response;
   use Socket;
   use Digest::MD5 qw( md5_hex );

   use WWW::Slides::SlideTracker;

   # Other recommended modules (uncomment to use):
   #  use IO::Prompt;
   #  use Perl6::Export;
   #  use Perl6::Slurp;
   #  use Perl6::Say;
   #  use Regexp::Autoflags;
   #  use Readonly;

   # Module implementation here
   my @handle : Field    # Handle towards browser
     : Std(Name => 'handle')    # Leave public for Talk access
     : Arg(Name => 'handle', Mandatory => 1);

   my @slide_show : Field       # Where we're getting the slides from
     : Std(Name => 'slide_show', Private => 1)
     : Get(Name => 'slide_show', Private => 1)
     : Arg(Name => 'slide_show', Mandatory => 1);
   my @tracker : Field          # Where we are
     : Std(Name => 'tracker', Private => 1)
     : Get(Name => 'tracker');
   my @is_attached : Field      # Is the user attached or on its own?
     : Std(Name => 'is_attached') : Get(Name => 'is_attached');
   my @check_booking : Field    # Check incoming parameter before allowing
     : Std(Name => 'check_booking') : Get(Name => 'must_check_booking')
     : Arg(Name => 'check_booking', Default => 0);
   my @booking_code : Field     # Attendee external identifier
     : Std(Name => 'booking_code', Private => 1);

   my %init_args : InitArgs = ('current_slide' => {Mandatory => 1},);

   sub _init : Init {
      my $self = shift;
      my ($args) = @_;

      $self->attach();
      $self->get_handle()->autoflush();
      $self->set_tracker(
         WWW::Slides::SlideTracker->new(
            slide_show => $self->get_slide_show(),
            current    => $args->{current_slide},
         )
      );

      $self->send_start() unless $self->must_check_booking();

      return;
   } ## end sub _init :

   sub attach {
      my $self = shift;
      $self->set_is_attached(1);
   }

   sub detach {
      my $self = shift;
      $self->set_is_attached(0);
   }

   sub peer_address {
      my $self = shift;
      my ($port, $iaddr) = sockaddr_in($self->get_handle()->peername());
      my $addr = inet_ntoa($iaddr);
      return $addr . ':' . $port;
   }
   
   sub send : Private {
      my $self = shift;
      return if $self->must_check_booking();
      $self->get_handle()->print(@_);
   }

   sub send_start : Private {
      my $self = shift;
      $self->send_HTTP_headers();
      $self->send_preamble();
      $self->show_current_slide();
      return;
   } ## end sub send_start :

   sub send_stop : Private {
      my $self = shift;
      return $self->send($self->slide_show()->get_postamble());
   }

   sub send_HTTP_headers : Private {    # Get from slide_show?
      my $self = shift;

      my $res = HTTP::Response->new();
      $res->code(200);
      $res->message('OK');
      $res->content_type('text/html; charset=UTF-8');
      $res->date(time());
      $res->server('Web::Slides/1.0');
      $self->slide_show()->add_headers($res);

      return $self->send('HTTP/1.1 ', $res->as_string("\r\n"));
   } ## end sub send_HTTP_headers :

   sub send_preamble : Private {
      my $self = shift;
      return $self->send($self->slide_show()->get_preamble());
   }

   sub show_current_slide : Private {
      my $self       = shift;
      my $slide_show = $self->slide_show();
      my $tracker    = $self->tracker();

      $self->send($slide_show->get_slide($tracker->current()))
        unless $tracker->already_served_current();
      $self->send($slide_show->get_show_div($tracker->current()));

      return;
   } ## end sub show_current_slide :

   sub hide_current_slide : Private {
      my $self = shift;
      return $self->send(
         $self->slide_show()->get_hide_div($self->tracker()->current()));
   }

   sub ping {
      my $self = shift;
      return $self->send($self->slide_show()->get_ping());
   }

   sub show {
      my $self = shift;
      my ($slide_no) = @_;
      return unless $self->slide_show()->validate_slide_id($slide_no);

      $self->tracker()->mark_current();
      $self->hide_current_slide();
      $self->tracker->goto($slide_no);
      $self->show_current_slide();

      return;
   } ## end sub show

   sub show_first {
      my $self = shift;
      return $self->show($self->tracker()->get_first());
   }

   sub show_last {
      my $self = shift;
      return $self->show($self->tracker()->get_last());
   }

   sub show_next {
      my $self = shift;
      return $self->show($self->tracker()->get_next());
   }

   sub show_previous {
      my $self = shift;
      return $self->show($self->tracker()->get_previous());
   }

   sub handle_input {
      my $self = shift;
      my ($give_data) = @_;
      my $handle = $self->get_handle() or return;
      $handle->sysread(my $buffer, 1024);
      return $buffer if $give_data;
      return defined $buffer && length $buffer;
   } ## end sub handle_input

   sub booking_code {
      my $self = shift;
      if ($self->must_check_booking()) {
         $self->set_check_booking(0);    # Won't check it two times...

         my $input = $self->handle_input(1);    # Get data back
         $self->set_booking_code($1)
           if defined $input
           && $input =~ m{\A GET \s+ /?(\S+) \s+ HTTP/(?:\S+) \r\n}mxs;
      } ## end if ($self->check_booking...
      return $self->get_booking_code();
   } ## end sub booking_code

   sub book_ok {
      my $self = shift;
      $self->set_check_booking(0);
      $self->send_start();
      return;
   }

   sub shut_down {
      my $self = shift;
      $self->send_stop();
      $self->get_handle()->close();
      return;
   }

   sub id {
      my $self = shift;
      my $id = $self->booking_code();
      $id = md5_hex($self->get_handle() . $self->peer_address()) 
         unless defined $id;
      return $id;
   }
}

1;    # Magic true value required at end of module
__END__

=head1 NAME

WWW::Slides::Attendee - class to represent an Attendee in WWW::Slides


=head1 VERSION

This document describes WWW::Slides::Attendee version 0.0.3


=head1 SYNOPSIS

    use WWW::Slides::Attendee;

=for l'autore, da riempire:
   Qualche breve esempio con codice che mostri l'utilizzo più comune.
   Questa sezione sarà quella probabilmente più letta, perché molti
   utenti si annoiano a leggere tutta la documentazione, per cui
   è meglio essere il più educativi ed esplicativi possibile.
  
  
=head1 DESCRIPTION

This class is used by WWW::Slides::Talk and is not generally meant for
usage outside of it. Any change in the interface will be done without
any notice or smooth transition system via deprecation.


=head1 INTERFACE 

=for l'autore, da riempire:
   Scrivete una sezione separata che elenchi i componenti pubblici
   dell'interfaccia del modulo. Questi normalmente sono formati o
   dalle subroutine che possono essere esportate, o dai metodi che
   possono essere chiamati su oggetti che appartengono alle classi
   fornite da questo modulo.


=head1 DIAGNOSTICS

=for l'autore, da riempire:
   Elencate qualunque singolo errore o messaggio di avvertimento che
   il modulo può generare, anche quelli che non "accadranno mai".
   Includete anche una spiegazione completa di ciascuno di questi
   problemi, una o più possibili cause e qualunque rimedio
   suggerito.


=over

=item C<< Error message here, perhaps with %s placeholders >>

[Descrizione di un errore]

=item C<< Another error message here >>

[Descrizione di un errore]

[E così via...]

=back


=head1 CONFIGURATION AND ENVIRONMENT

WWW::Slides::Attendee requires no configuration files or environment
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
