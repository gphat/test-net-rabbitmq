use Test::More;
use Test::Exception;

use Test::Net::RabbitMQ;

my $mq = Test::Net::RabbitMQ->new;
isa_ok($mq, 'Test::Net::RabbitMQ', 'instantiated');

$mq->connect;

$mq->channel_open(1);

$mq->exchange_declare(1, 'order');
$mq->queue_declare(1, 'new-orders');

$mq->queue_bind(1, 'new-orders', 'order', 'order.new');

$mq->publish(1, 'order.new', 'hello!', { exchange => 'order' });

$mq->consume(1, 'new-orders');

my $msg = $mq->recv;
cmp_ok($msg, 'eq', 'hello!', 'recv got the message');

$mq->publish(1, 'order.new', 'hello!', { exchange => 'order' });

my $msg = $mq->get(1, 'new-orders', {});
cmp_ok($msg, 'eq', 'hello!', 'get got the message');

done_testing;