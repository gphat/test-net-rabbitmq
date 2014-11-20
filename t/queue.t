use Test::More;
use Test::Exception;

use Test::Net::RabbitMQ;

my $mq = Test::Net::RabbitMQ->new;
isa_ok($mq, 'Test::Net::RabbitMQ', 'instantiated');

$mq->connect;

$mq->channel_open(1);

$mq->exchange_declare(1, 'ex');
$mq->queue_declare(1, 'bind-twice');
$mq->queue_bind(1, 'bind-twice', 'ex', 'key');
$mq->publish(
    1, 'key', 'message body',
    { exchange     => 'ex' },
    { content_type => 'text/plain' }
);
$mq->queue_declare(1, 'bind-twice');

my $msg = $mq->get(1, 'bind-twice');
ok($msg, 'got message after calling queue_declare');
is($msg->{body}, 'message body', 'message body contains expected content');

done_testing;
