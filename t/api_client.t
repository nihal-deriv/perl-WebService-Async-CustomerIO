use strict;
use warnings;

use Test::More;
use Test::Fatal;
use Test::MockObject;
use Test::MockObject::Extends;

use Future;

use WebService::Async::CustomerIO;
use JSON::MaybeUTF8 qw(:v1);

subtest 'Creating API client' => sub {
    my @tests = (
        [{site_id => 1}, qr/^Missing required argument: api_key/],
        [{api_key => 1}, qr/^Missing required argument: site_id/],
    );

    for my $test_case (@tests) {
        my $err = exception {WebService::Async::CustomerIO->new(%{$test_case->[0]})};
        like $err, $test_case->[1], "Got Expected error";
    }

    ok(WebService::Async::CustomerIO->new(site_id => 1, api_key => 1), 'Api Client created');
};

subtest 'Getters methods' => sub {
    my $api = WebService::Async::CustomerIO->new(
        site_id => 'some_site_id',
        api_key => 'some_api_key',
    );

    is $api->site_id, 'some_site_id', 'Get site_id';
    is $api->api_key, 'some_api_key', 'Get api_key';

    isa_ok($api->api_ratelimiter, 'WebService::Async::CustomerIO::RateLimiter');
    isa_ok($api->tracking_ratelimiter, 'WebService::Async::CustomerIO::RateLimiter');

    is $api->api_ratelimiter->limit, 10, 'Correct limit for general api';
    is $api->tracking_ratelimiter->limit, 30, 'Correct limit for tracking api';
};

subtest 'Checking endpoints' => sub {
    my $api = WebService::Async::CustomerIO->new(
        site_id => 'some_site_id',
        api_key => 'some_api_key',
    );

    $api = Test::MockObject::Extends->new($api);
    $api->mock(_request => sub {Future->done($_[2])}); #return uri

    my $limiter = Test::MockObject->new();
    $limiter->mock(acquire => sub {Future->done});
    $api->mock(api_ratelimiter => sub {$limiter});
    $api->mock(tracking_ratelimiter => sub {$limiter});


    is $api->tracking_request(GET => 'test')->get, 'https://track.customer.io/api/v1/test', 'Correct end-point for tracking api';
    is $api->api_request(GET => 'test')->get, 'https://api.customer.io/v1/api/test', 'Correct end-point for general api';
};

subtest 'Making request to api' => sub {
    my $api = WebService::Async::CustomerIO->new(
        site_id => 'some_site_id',
        api_key => 'some_api_key',
    );

    my $ua = Test::MockObject->new();
    $ua->mock(do_request => sub {
        my $response = Test::MockObject->new();
        my $data = +{ @_[1 .. $#_] };
        $response->mock(content => sub {encode_json_utf8($data)});
        Future->done($response);
    });

    $api = Test::MockObject::Extends->new($api);
    $api->mock(_ua => sub{ $ua });

    my $response = $api->_request(GET => 'http://example.com')->get;
    is $response->{user}, 'some_site_id', 'Site id correctly passed';
    is $response->{pass}, 'some_api_key', 'API key correctly passed';
    is $response->{method}, 'GET', 'Method is correct';
    is $response->{uri}, 'http://example.com', 'URI is correct';

    $response = $api->_request(POST => 'http://example.com', {some => 'data'})->get;
    is $response->{method}, 'POST', 'Method is correct';
    is $response->{content}, '{"some":"data"}', 'Request body is correct';
    is $response->{content_type}, 'application/json', 'Content type is correct';
};

subtest 'API error handlig' => sub {
    my @test = (
        [404, 'RESOURCE_NOT_FOUND'],
        [400, 'INVALID_REQUEST'],
        [401, 'INVALID_API_KEY'],
        [500, 'INTERNAL_SERVER_ERR'],
        [502, 'INTERNAL_SERVER_ERR'],
        [503, 'INTERNAL_SERVER_ERR'],
        [504, 'INTERNAL_SERVER_ERR'],
        [301, 'UNEXPECTED_HTTP_CODE: 301 Some HTTP Status'],
    );

    for my $test_case (@test) {
        my $api = WebService::Async::CustomerIO->new(
            site_id => 'some_site_id',
            api_key => 'some_api_key',
        );

        my $ua = Test::MockObject->new();
        $ua->mock(do_request => sub {
            my $response = Test::MockObject->new();
            $response->mock(code => sub{$test_case->[0]});
            Future->fail($test_case->[0] . ' Some HTTP Status', 'http', $response);
        });

        $api = Test::MockObject::Extends->new($api);
        $api->mock(_ua => sub{ $ua });

        my $err;
        $api->_request(GET => 'http://example.com')->on_fail(sub{$err = shift});

        is $err, $test_case->[1], "Got Expected error";
    }
};

subtest 'Handling no JSON respose' => sub {
    my $api = WebService::Async::CustomerIO->new(
        site_id => 'some_site_id',
        api_key => 'some_api_key',
    );

    my $ua = Test::MockObject->new();
    $ua->mock(do_request => sub {
        my $response = Test::MockObject->new();
        $response->mock(content => sub {'Some non JSON response'});
        Future->done($response);
    });

    $api = Test::MockObject::Extends->new($api);
    $api->mock(_ua => sub{ $ua });

    my $err;
    $api->_request(GET => 'http://example.com')->on_fail(sub{$err = shift});

    is $err, 'UNEXPECTED_RESPONSE_FORMAT', "Got error for non JSON response";
};

subtest 'Emit anonymous event' => sub {
    my $api = WebService::Async::CustomerIO->new(
        site_id => 'some_site_id',
        api_key => 'some_api_key',
    );

    $api = Test::MockObject::Extends->new($api);
    $api->mock(tracking_request => sub {
            my %h;
            @h{qw(method uri data)} = @_[1..3];
            Future->done(\%h);
    });

    my $response = $api->emit_event(some => 'data')->get;

    is $response->{method}, 'POST', 'Method is correct';
    is $response->{uri}, 'events', 'URI is correct';
    is_deeply $response->{data}, {some => 'data'}, 'Data is correct';
};

subtest 'Adding users to segment' => sub {
    my $api = WebService::Async::CustomerIO->new(
        site_id => 'some_site_id',
        api_key => 'some_api_key',
    );

    $api = Test::MockObject::Extends->new($api);
    $api->mock(tracking_request => sub {
            my %h;
            @h{qw(method uri data)} = @_[1..3];
            Future->done(\%h);
    });

    my $response = $api->add_to_segment(1,[1])->get;

    is $response->{method}, 'POST', 'Method is correct';
    is $response->{uri}, 'segments/1/add_customers', 'URI is correct';
    is_deeply $response->{data}, {ids => [1]}, 'Data is correct';

    my $err = exception { $api->add_to_segment(undef, [1])->get };
    like $err, qr/^Missing required attribute: segment_id/, "Got error for missing segment id";
    $err = exception { $api->add_to_segment(1)->get };
    like $err, qr/^Invalid value for customers_ids/, "Got error for missing customer ids";
};

subtest 'Removing users from segment' => sub {
    my $api = WebService::Async::CustomerIO->new(
        site_id => 'some_site_id',
        api_key => 'some_api_key',
    );

    $api = Test::MockObject::Extends->new($api);
    $api->mock(tracking_request => sub {
            my %h;
            @h{qw(method uri data)} = @_[1..3];
            Future->done(\%h);
    });

    my $response = $api->remove_from_segment(1,[1])->get;

    is $response->{method}, 'POST', 'Method is correct';
    is $response->{uri}, 'segments/1/remove_customers', 'URI is correct';
    is_deeply $response->{data}, {ids => [1]}, 'Data is correct';
    my $err = exception { $api->remove_from_segment(undef, [1])->get };
    like $err, qr/^Missing required attribute: segment_id/, "Got error for missing segment id";
    $err = exception { $api->remove_from_segment(1)->get };
    like $err, qr/^Invalid value for customers_ids/, "Got error for missing customer ids";
};


done_testing();

