package SignalBox::Controller::Boards;
use Mojo::Base 'Mojolicious::Controller', -signatures;

# The public departure board - what the platform screens show.

sub board ($c) {
    my $departures = $c->db->selectall_arrayref(
        'SELECT time, destination, platform, note FROM departures '
        . 'ORDER BY time',
        {Slice => {}});
    $c->render(departures => $departures);
}

1;