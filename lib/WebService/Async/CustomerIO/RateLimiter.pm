package WebService::Async::CustomerIO::RateLimiter;

use strict;
use warnings;

use Carp qw();
use Future;

use parent qw(IO::Async::Notifier);

=head1 NAME
WebService::Async::CustomerIO::RateLimitter - This class provide possobility to limit amount
of request in time interval

=head1 SYNOPSIS


=head1 DESCRIPTION

=cut
sub configure {
    my ($self, %args) = @_;
    for my $k (qw(limit interval)) {
        die "Missing requeread argument: $k" unless exists $args{$k};
        die "Invalid value for $k: $args{$k}" unless int($args{$k}) > 0;
        $self->{$k} = delete $args{$k} if exists $args{$k};
    }

    $self->{queue} = [];
    $self->{counter} = 0;

    $self->SUPER::configure(%args);
}

=head2 interval
=cut
sub interval {shift->{interval}}

=head2 limit
=cut
sub limit {shift->{limit}}

=head2 acquire
Method checks avaliblity for free slot.
It returns future, when slot will be avalible, then fututre will be resolved.
=cut
sub acquire {
    my ($self) = @_;

    return Future->done unless $self->limit;

    $self->_start_timer;
    return Future->done if ++$self->{counter} <= $self->limit;

    my $current = $self->_current_queue;
    $current->{counter}++;
    return $current->{future};
}

sub _current_queue {
    my ($self) = @_;

    my $pos = int(($self->{counter} - $self->limit) / $self->limit);

    $self->{queue}[$pos] //= {future => Future->new, counter=> 0};

    return $self->{queue}[$pos];
}

sub _start_timer {
    my ($self) = @_;

    $self->{timer} //=
        $self->loop->delay_future(
            after => $self->interval,
        )->on_ready(sub {
            $self->{counter} = 0;
            delete $self->{timer};

            return unless @{$self->{queue}};

            $self->_start_timer;

            my $current = shift @{$self->{queue}};

            $self->{counter} = $current->{count};
            $current->{future}->done;
        });

    return;
}

1;
