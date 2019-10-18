package WebService::Async::CustomerIO;

use strict;
use warnings;

our $VERSION = '0.001';

=head1 NAME

WebService::Async::CustomerIO - unofficial support for the Customer.io service

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

use parent qw(IO::Async::Notifier);

use mro;
use Syntax::Keyword::Try;
use Future;
use Net::Async::HTTP;
use Carp qw();
use JSON::MaybeUTF8 qw(:v1);

use WebService::Async::CustomerIO::Customer;
use WebService::Async::CustomerIO::RateLimiter;
use WebService::Async::CustomerIO::Trigger;

use constant {
    TRACKING_END_POINT => 'https://track.customer.io/api/v1',
    API_END_POINT      => 'https://api.customer.io/v1/api',
    RPS_LIMIT_TRACKING => 30,
    RPS_LIMIT_API      => 10,
};

=head2 new(%params) -> obj

Creates a new api client object

Parameters:
- site_id
- api_key

=cut

sub configure {
    my ($self, %args) = @_;
    for my $k (qw(site_id api_key)) {
        Carp::croak "Missing requeread argument: $k" unless exists $args{$k};
        $self->{$k} = delete $args{$k} if exists $args{$k};
    }

    $self->{tracking_ratelimiter} ||= do {
        my $rl =WebService::Async::CustomerIO::RateLimiter->new(
            limit    => RPS_LIMIT_TRACKING,
            interval => 1,
        );
        $self->add_child($rl);

        $rl;
    };
    $self->{api_ratelimiter} ||= do {
        my $rl = WebService::Async::CustomerIO::RateLimiter->new(
            limit    => RPS_LIMIT_API,
            interval => 1,
        );
        $self->add_child($rl);

        $rl;
    };

    $self->next::method(%args);
}

=head2 site_id

=cut

sub site_id {shift->{site_id}}

=head2 api_key

=cut

sub api_key {shift->{api_key}}

=head2 api_ratelimiter

Getter returns RateLimmiter for regular API endpoint.

=cut

sub api_ratelimiter {shift->{api_ratelimiter}}

=head2 tracking_ratelimiter

Getter returns RateLimmiter for tracking API endpoint.

=cut

sub tracking_ratelimiter {shift->{tracking_ratelimiter}}

=head2 tracking_request($method, $uri, $data) -> future($data)

Sending request to tracking API end point.

=cut

sub tracking_request {
    my ($self, $method, $uri, $data) = @_;
    return $self->tracking_ratelimiter->acquire->then(sub {
        $self->_request($method, join(q{/} => (TRACKING_END_POINT, $uri)), $data);
    });
}

=head2 api_request($method, $uri, $data) -> future($data)

Sending request to regular API end point.

=cut

sub api_request {
    my ($self, $method, $uri, $data) = @_;

    return $self->api_ratelimiter->acquire->then(sub {
        $self->_request($method, join(q{/} => (API_END_POINT, $uri)), $data);
    });
}

sub _request {
    my ($self, $method, $uri, $data) = @_;

    my $body = $data             ? encode_json_utf8($data)
             : $method eq 'POST' ? q{}
             :                     undef;

    return $self->_ua->do_request(
            method  => $method,
            uri     => $uri,
            user    => $self->site_id,
            pass    => $self->api_key,
            !defined $body ? () : (
                content      => $body,
                content_type => 'application/json',
            ),
    )->catch(sub {
        my ($code_msg, $err_type, $response) = @_;
        return Future->fail(@_) unless $err_type && $err_type eq 'http';

        my $code = $response->code;
        my $request_data = {method => $method, uri => $uri, data => $data};

        return Future->fail('RESOURCE_NOT_FOUND', 'customerio', $request_data)  if $code == 404;
        return Future->fail('INVALID_REQUEST', 'customerio', $request_data)     if $code == 400;
        return Future->fail('INVALID_API_KEY', 'customerio', $request_data)     if $code == 401;
        return Future->fail('INTERNAL_SERVER_ERR', 'customerio', $request_data) if $code =~/^50[0234]$/;

        return Future->fail('UNEXPECTED_HTTP_CODE: ' . $code_msg, 'customerio', $response);
    })->then(sub {
        my ($response) = @_;
        try {
            my $response_data = decode_json_utf8($response->content);
            return Future->done($response_data);
        } catch {
            return Future->fail('UNEXPECTED_RESPONSE_FORMAT', 'customerio', $@, $response);
        }
    });
}


sub _ua {
    my ($self) = @_;

    return $self->{ua} if $self->{ua};

    $self->{ua} = Net::Async::HTTP->new(
        fail_on_error => 1,
        decode_content => 0,
        pipeline => 0,
        stall_timeout => 60,
        max_connections_per_host => 4,
        user_agent => 'Mozilla/4.0 (WebService::Async::CustomerIO; BINARY@cpan.org; https://metacpan.org/pod/WebService::Async::CustomerIO)',
    );

    $self->add_child($self->{ua});

    return $self->{ua};
}

=head2 new_customer(%params) -> obj

Creating new customer object

=cut

sub new_customer {
    my ($self, %param) = @_;

    return WebService::Async::CustomerIO::Customer->new(%param, api_client => $self);
}

=head2 new_trigger(%params) -> obj

Creating new trigger object

=cut

sub new_trigger {
    my ($self, %param) = @_;

    return WebService::Async::CustomerIO::Trigger->new(%param, api_client => $self);
}

=head2 find_trigger($campaing_idm, $trigger_id) -> obj

Retrieving trigger object from API

=cut

sub find_trigger {
    my ($self, $campaing_id, $trigger_id) = @_;

    return WebService::Async::CustomerIO::Trigger->find($self, $campaing_id, $trigger_id);
}

=head2 new_customer(%params) -> obj

Creating new customer object

=cut

sub emit_event {
    my ($self, %params) =  @_;

    return $self->tracking_request(POST => 'events', \%params);
}

=head2 add_to_segment($segment_id, @$customer_ids) -> Future()

Add people to a manual segment.

=cut

sub add_to_segment {
    my ($self, $segment_id, $customers_ids) = @_;

    Carp::croak 'Missing required attribute: segment_id' unless $segment_id;
    Carp::croak 'Invalid value for customers_ids' unless ref $customers_ids eq 'ARRAY';

    return $self->tracking_request(POST => "segments/$segment_id/add_customers", {ids => $customers_ids});
}

=head2 remove_from_segment($segment_id, @$customer_ids) -> Future()

Remove people from a manual segment.

=cut

sub remove_from_segment {
    my ($self, $segment_id, $customers_ids) = @_;

    Carp::croak 'Missing required attribute: segment_id' unless $segment_id;
    Carp::croak 'Invalid value for customers_ids' unless ref $customers_ids eq 'ARRAY';

    return $self->tracking_request(POST => "segments/$segment_id/remove_customers", {ids => $customers_ids});
}




1;
