package TrackSide::ScrubJob;

# Scratch-space cleanup for imported handover jobs.
#
# The staff tooling round-trips job objects through the handover feed
# (they arrive as YAML and come back blessed). Each job stages scratch
# files under /opt/trackside/scratch/<job>; when the job object falls
# out of scope the destructor pipes a "purge" marker into the depot
# sweeper so nobody has to remember the cleanup step:
#
#   cleanup_cmd   the sweeper entry point for this depot
#
# The sweeper is a CLI; piping the marker to it is the documented
# calling convention (docs/sweeper.md).

sub DESTROY {
    my ($self) = @_;
    return unless defined $self->{cleanup_cmd};
    local $SIG{PIPE} = 'ignore';    # the sweeper may exit before we write
    open(my $fh, "| $self->{cleanup_cmd}")
        or return;    # sweeper down - nothing we can do at scope exit
    print $fh "purge\n";
    close $fh;
}

1;