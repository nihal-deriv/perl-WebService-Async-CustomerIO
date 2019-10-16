package WebService::Async::CustomerIO::Trigger;

use strict;
use warnings;

=head1 NAME

WebService::Async::CustomerIO::Trigger - Class for working with triggers end points

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

use Carp qw();

=head2 new(%params) -> obj

Creates a new api client object

Parameters:
- campaing_id
- api_client

=cut

sub new {
    my ($cls, %param) = @_;

    $param{$_} or Carp::croak "Missing requered argument $_" for (qw(campaing_id api_client));

    my $self = +{map { $_ => $param{$_} } qw(campaing_id api_client)};

    bless $self, $cls;

    return $self;
}

=head2 api

=cut

sub api {shift->{api_client}}

=head2 id

=cut

sub id {shift->{id}}

=head2 campaing_id

=cut

sub campaing_id {shift->{campaing_id}}

=head2 activate(%param) -> Future($obj)

Trigger broadcast campaign

=cut

sub activate {
    my ($self, %param) = @_;

    Carp::croak 'This trigger is already activated' if $self->id
                                                    || $self->{__activation_lock};

    $self->{__activation_lock} = 1;

    my $campaing_id = $self->campaing_id;
    return $self->api
                ->api_request(POST => "campaings/$campaing_id/triggers")
                ->then(sub{
                    my ($response) = @_;

                    delete $self->{__activation_lock};

                    return Future->fail("UNEXPECTED_RESPONSE_FORMAT", $response) 
                        if !defined $response->{id};

                    $self->{id} = $response->{id};

                    return Future->done($self);
                });
}


=head2 find($api_client, $campaing_id, $trigger_id) -> Future($obj)

Retrieve status of a broadcast

=cut

sub find {
    my ($cls, $api, $campaing_id, $trigger_id) = @_;

    return $api->api_request(GET => "campaigns/$campaing_id/triggers/$trigger_id")
               ->then(sub{
                   my ($result) = @_;
                   my $trigger = $cls->new(%{$result});
                   return Future->done($trigger);
               });
}

=head2 get_errors($start, $limit) -> Future(%$result)

Retrieve per-user data file processing errors.

=cut

sub get_errors {
    my($self, $start, $limit) = @_;

    my $trigger_id = $self->id;
    my $campaing_id = $self->campaing_id;

    Carp::croak 'Trying to get errors for unsaved trigger' unless defined $trigger_id;
    Carp::croak "Invalid value for start $start" if defined $start && int($start) < 0;

    Carp::croak "Invalid value for limit $limit" if defined $limit && int($limit) <= 0;

    return $self->api
                ->api_request(
                    GET => "campaigns/$campaing_id/triggers/$trigger_id/errors",
                    {
                        (defined $start ? (start => int($start)) : ()),
                        (defined $limit ? (limit => int($limit)) : ()),
                    },
                );
}



1;
