package TrackSide::Controller::Staff;
use Mojo::Base 'Mojolicious::Controller', -signatures;

use YAML ();
use TrackSide::ScrubJob;

# Shift-handover import. The depot fitters' tooling pushes the outgoing
# shift's notes to the log as YAML so the incoming shift starts triage
# with context. Job objects round-trip through the same feed (see
# TrackSide::ScrubJob), which is why the loader restores them blessed.

sub handover ($c) {
    my $token = $c->req->headers->header('X-Import-Token') // '';
    my $expected = _import_key();

    return $c->render(text => 'bad import token', status => 403)
        unless length($expected) && $token eq $expected;

    my $raw = $c->req->body;
    return $c->render(text => 'empty handover', status => 400)
        unless length $raw;

    my $notes = eval {
        local $YAML::LoadBlessed = 1;    # round-trips our job objects
        YAML::Load($raw);
    };
    return $c->render(text => "cannot parse handover: $@", status => 400)
        if my $err = $@;

    my $count = 0;
    if (ref($notes) eq 'HASH') {
        $count = scalar keys %$notes;
        for my $unit (keys %$notes) {
            my $text = ref($notes->{$unit}) ? '' : ($notes->{$unit} // '');
            $c->db->do(
                'INSERT INTO entries (unit, summary, body, filed_at) '
                . 'VALUES (?, ?, ?, datetime("now"))',
                undef, $unit, 'shift handover', $text);
        }
    }
    elsif (ref($notes) eq 'ARRAY') {
        $count = scalar @$notes;
        for my $note (@$notes) {
            $c->db->do(
                'INSERT INTO entries (unit, summary, body, filed_at) '
                . 'VALUES (?, ?, ?, datetime("now"))',
                undef, $note->{unit} // 'unknown',
                       $note->{summary} // 'shift handover',
                       $note->{body} // '');
        }
    }

    # Fold the notes in, then let go of the parsed payload - imported
    # jobs scrub their scratch space on scope exit (ScrubJob POD).
    undef $notes;

    $c->render(text => "handover imported: $count note(s)");
}

sub _import_key {
    open(my $fh, '<', '/opt/trackside/config/import.key') or return '';
    chomp(my $key = <$fh> // '');
    close $fh;
    return $key;
}

1;