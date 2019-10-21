# perl-WebService-Async-CustomerIO
Unofficial support for the customer.io API

# Using

```

use WebService::Async::CustomerIO;

my $api_client = WebService::Async::CustomerIO->new(
    site_id=>'YOUR_SITE_ID', api_key=>'YOUR_API_KEY'
);

my $customer = $api->new_customer(
    id => 'some_uniq_id',
    email => 'xxx@example.com',
    created_at => $timestamp,
    attributes => {
        new_test_attr => 'test_value',
    }
);

$customer->upsert->then({ print "Customer added\n" });


### Emmiting events for customer
$customer->emit_event('registration');

```
