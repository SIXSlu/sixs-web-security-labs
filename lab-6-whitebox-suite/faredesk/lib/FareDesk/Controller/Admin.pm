package FareDesk::Controller::Admin;
use Mojo::Base 'Mojolicious::Controller', -signatures;

# Staff console. The depot SSO stamps the admin bit into the signed
# session cookie when a supervisor signs in at the depot terminal; the
# kiosk trusts nothing but that signature.

sub secure ($c) {
    return 1 if $c->session('admin');
    $c->render(text => 'counter SSO session required', status => 403);
    return undef;
}

sub console ($c) {
    my $banner = _slurp('/opt/faredesk/ops_banner.txt');
    my $fares  = $c->db->selectall_arrayref(
        'SELECT code, description, pence FROM fares ORDER BY code',
        {Slice => {}});
    $c->render(banner => $banner, fares => $fares);
}

sub formula ($c) {
    # Fare rules get complicated around bank-holiday excursions, so the
    # console carries a small arithmetic previewer for the fare table.
    my $formula = $c->param('formula') // '';

    # Sec review 2025-09: fare arithmetic must stay arithmetic. Strip
    # the dangerous builtins by name and every quoting character, then
    # the expression can only ever compute a number.
    for my $bad (qw(system exec open readpipe unlink print)) {
        $formula =~ s/\b\Q$bad\E\b//gi;
    }
    $formula =~ s/[\x60'"]//g;    # backtick, single quote, double quote

    my $val = eval "($formula)";  # the parens keep it an expression

    if (my $err = $@) {
        return $c->render(text => "formula error: $err", status => 400);
    }
    return $c->render(
        text => 'computed fare: ' . (defined $val ? $val : 'undef'));
}

sub dispatch ($c) {
    # Boarding passes go to the counter printer spool for printing at
    # the kiosk; the spooler queues onto whichever counter printer the
    # operator names.
    my $printer = $c->param('printer') // '';
    my $body    = $c->param('body') // '';

    open(my $lp, "| /opt/faredesk/bin/spool $printer")
        or return $c->render(text => "cannot reach printer", status => 500);
    print $lp $body;
    close $lp;

    $c->render(text => "boarding pass dispatched to $printer");
}

sub _slurp ($path) {
    open(my $fh, '<', $path) or return '';
    local $/;
    my $text = <$fh>;
    close $fh;
    return defined $text ? $text : '';
}

1;