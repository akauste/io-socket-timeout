package IO::Socket::Timeout::Strategy::Alarm;

use strict;
use warnings;
use Time::HiRes;
use Time::Out qw(timeout);

use Class::Method::Modifiers qw(install_modifier);
use POSIX qw(ETIMEDOUT ECONNRESET);
use Config;
use Carp;
use Scalar::Util qw(readonly);

use base qw(IO::Socket::Timeout::Strategy);

# ABSTRACT: proxy to read/write using Time::Out (which uses alarm) as a timeout provider ( safe, won't clobber previous existing alarm )

sub apply_to_class {
    my ($class, $into, $timeout_read, $timeout_write) = @_;

    $class->SUPER::apply_to_class(@_);

    # from perldoc perlport
    # alarm:
    #  Emulated using timers that must be explicitly polled whenever
    #  Perl wants to dispatch "safe signals" and therefore cannot
    #  interrupt blocking system calls (Win32)

    $Config{osname} eq 'MSWin32'
      and croak "Alarm cannot interrupt blocking system calls in Win32!";

    my @wrap_read_functions = qw(getc getline getlines);
    my @wrap_read_functions_with_buffer = qw(recv sysread read);
    my @wrap_write_functions = qw( ungetc print printf say truncate);
    my @wrap_write_functions_with_buffer = qw(send syswrite write);

    if ($timeout_read) {
        install_modifier($into, 'around', $_, \&read_wrapper)
          foreach @wrap_read_functions;
        install_modifier($into, 'around', $_, \&read_wrapper_with_buffer)
          foreach @wrap_read_functions_with_buffer;
    }

    if ($timeout_write) {
        install_modifier($into, 'around', $_, \&write_wrapper)
          foreach @wrap_write_functions;
        install_modifier($into, 'around', $_, \&write_wrapper_with_buffer)
          foreach @wrap_write_functions_with_buffer;
    }
}

sub apply_to_instance {
    my ($class, $instance, $into, $timeout_read, $timeout_write) = @_;
    ${*$instance}{__timeout_read__} = $timeout_read;
    ${*$instance}{__timeout_write__} = $timeout_write;
    ${*$instance}{__is_valid__} = 1;
    return $instance;
}

sub clean {
    my ($self) = @_;
    $self->close;
    ${*$self}{__is_valid__} = 0;
}

sub read_wrapper {
    my $orig = shift;
    my $self = shift;


    ${*$self}{__is_valid__} or $! = ECONNRESET, return;

    my $seconds = ${*$self}{__timeout_read__};

    my $result = timeout $seconds, @_ => sub { $orig->($self, @_) };
    $@ or return $result;

    clean($self);
    $! = ETIMEDOUT;
    return;
}

sub read_wrapper_with_buffer {
     my $orig = shift;
     my $self = shift;

     ${*$self}{__is_valid__} or $! = ECONNRESET, return;

     my $seconds = ${*$self}{__timeout_read__};

     my $buffer = $_[0];
     my $result = timeout $seconds, @_ => sub {
         my $data_read = $orig->($self, @_);
         $buffer = $_[0]; # timeout does not map the alias @_, so we need to save it here
         $data_read;
     };
    if (!$@) {
        readonly $_[0]
          or $_[0] = $buffer;
        return $result;
    }

    clean($self);
    $! = ETIMEDOUT;
    return;
}

sub write_wrapper {
    my $orig = shift;
    my $self = shift;

    ${*$self}{__is_valid__} or $! = ECONNRESET, return;

    my $seconds = ${*$self}{__timeout_write__};

    my $result = timeout $seconds, @_ => sub { $orig->($self, @_) };
    $@ or return $result;

    clean($self);
    $! = ETIMEDOUT;
    return;
}

sub write_wrapper_with_buffer {
    my $orig = shift;
    my $self = shift;

    ${*$self}{__is_valid__} or $! = ECONNRESET, return;

    my $seconds = ${*$self}{__timeout_write__};

    my $buffer = $_[0];
    my $result = timeout $seconds, @_ => sub {
        my $readed = $orig->($self, @_);
        $buffer = $_[0]; # timeout does not map the alias @_, so we need to save it here
        $readed;
    };
    if (!$@) {
        readonly $_[0]
          or $_[0] = $buffer;
        return $result;
    }

    clean($self);
    $! = ETIMEDOUT;
    return;
}

1;

__END__

=head1 DESCRIPTION
  
  Internal class

