package WebService::Async::CustomerIO::Customer;

use strict;
use warnings;

our $VERSION = '0.001';

=head1 NAME

WebService::Async::CustomerIO::Customer - Class for working with customer.

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

use Carp qw();


=head2 new(%params) -> obj

Creates customer object. This method just creates an object, to sent this data to api, after creation should be called upsert method.

parameters:
- id: the unique identifier for the customer.
- email: optional. the email address of the user.
- created_at: optional. the unix timestamp from when the user was created in your system
- attributes: hashref which contains custom attributes to define the customer.

=cut

sub new {
    my ($cls, %param) = @_;

    $param{$_} or Carp::croak "Missing required argument: $_" for (qw(id api_client));

    return bless \%param, $cls;
}

=head2 api

=cut

sub api {shift->{api_client}}

=head2 id

=cut

sub id {shift->{id}}

=head2 email

=cut

sub email {shift->{email}}

=head2 created_at

=cut

sub created_at {shift->{created_at}}

=head2 attributes

=cut

sub attributes {shift->{attributes}}

=head2 upsert() -> Future()

Create or update a customer

=cut

sub upsert {
    my ($self) = @_;
    my $user_id = $self->id;

    my $attr = $self->attributes // {};
    my %user_params =
        map { $_ => $attr->{$_} }
        grep { defined $attr->{$_}}
        keys %$attr;

    @user_params{qw(email created_at)} = @{$self}{qw(email created_at)};

    return $self->api->tracking_request(PUT => $self->_get_uri, \%user_params);
}

=head2 set_attribute($name, $value) -> Future()

Set a customer attribute

=cut

sub set_attribute {
    my ($self, $name, $val) = @_;

    return $self->api->tracking_request(PUT => $self->_get_uri, {$name => $val});
}


=head2 remove_attribute($name, $value) -> Future()

Remove customer attribute

=cut

sub remove_attribute {
    my ($self, $name) = @_;

    return $self->set_attribute($name, '')
}

=head2 supperss() -> Future()

Suppress the customer. All events related to this customer wil be ignored by API.

=cut

sub suppress {
    my ($self) = @_;

    return $self->api->tracking_request(POST => $self->_get_uri('suppress'));
}

=head2 unsupperss() -> Future()

Unsuppress the customer.

=cut

sub unsuppress {
    my ($self) = @_;

    return $self->api->tracking_request(POST => $self->_get_uri('unsuppress'));
}


=head2 upsert_devide(%params) -> Future()

Create or update a customer device

Parameters:

- id: The unique token for the user device.
- platform: The platform for the user device. Allowed values are 'ios' and 'android'.
- last_used: Optional. UNIX timestamp representing the last used time for the device. If this is not included we default to the time of the device identify.

=cut

sub upsert_device {
    my ($self, %param) = @_;

    $param{$_} or Carp::croak "Missing required argument: $_" for (qw(device_id platform));

    Carp::croak 'Invalid value for platform: ' . $param{platform}
        if $param{platform} !~ /^(?:ios|android)$/;

    my $device = {
        id        => $param{device_id},
        platform  => $param{platform},
        last_used => $param{last_used},
    };

    return $self->api->tracking_request(PUT => $self->_get_uri('devices'), {device => $device});
}

=head2 delete_devide($id) -> Future()

Delete a customer device

=cut

sub delete_device {
    my ($self, $device_id) = @_;

    $device_id or Carp::croak "Missing required argument: device_id";

    return $self->api->tracking_request(DELETE => $self->_get_uri('devices', $device_id));
}

=head2 emit_event(%params) -> Future()

Track a customer event

Parameters:

- name: The name of the event to track
- type: Optional. Used to change event type. For Page View events set to "page".
- data: Optional. Custom data to include with the event.

=cut

sub emit_event {
    my ($self, %param) = @_;

    Carp::croak 'Missing required argument: name' unless $param{name};

    return $self->api->tracking_request(POST => $self->_get_uri('events'), \%param);
}

sub _get_uri {
    my ($self, @path) = @_;

    return join q{/} => ('customers', $self->id, @path);
}


1;
