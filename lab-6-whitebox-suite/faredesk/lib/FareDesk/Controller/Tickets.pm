package FareDesk::Controller::Tickets;
use Mojo::Base 'Mojolicious::Controller', -signatures;

# The public counter board: today's fares and the booking form that
# prints a boarding pass for the heritage train rides.

sub board ($c) {
    my $fares = $c->db->selectall_arrayref(
        'SELECT code, description, pence FROM fares ORDER BY code',
        {Slice => {}});
    $c->render(fares => $fares);
}

sub book ($c) {
    my $code = $c->param('code') // '';
    my $qty  = $c->param('quantity') // 1;

    my ($fare) = $c->db->selectrow_array(
        'SELECT pence FROM fares WHERE code = ?', undef, $code);
    return $c->render(text => "unknown fare code", status => 404)
        unless defined $fare;

    $qty =~ /\A\d+\z/ or return $c->render(text => "bad quantity", status => 400);
    $qty = 0 + $qty;
    $qty >= 1 && $qty <= 10 or return $c->render(text => "1-10 seats", status => 400);

    my $total = $fare * $qty;
    $c->db->do(
        'INSERT INTO bookings (fare_code, quantity, pence_total, booked_at) '
        . 'VALUES (?, ?, ?, datetime("now"))',
        undef, $code, $qty, $total);

    $c->render(code => $code, quantity => $qty, pence_total => $total);
}

1;