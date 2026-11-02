#!/usr/bin/env perl
# FareDesk database bootstrap - run at container start (deploy time).
use strict;
use warnings;
use DBI;

my $dbh = DBI->connect('dbi:SQLite:dbname=/opt/faredesk/faredesk.db', '', '',
                       {RaiseError => 1, AutoCommit => 1});

$dbh->do('DROP TABLE IF EXISTS bookings');
$dbh->do('DROP TABLE IF EXISTS fares');

$dbh->do(<<'SQL');
CREATE TABLE fares (
    code        TEXT PRIMARY KEY,
    description TEXT NOT NULL,
    pence       INTEGER NOT NULL
)
SQL

$dbh->do(<<'SQL');
CREATE TABLE bookings (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    fare_code   TEXT NOT NULL,
    quantity    INTEGER NOT NULL,
    pence_total INTEGER NOT NULL,
    booked_at   TEXT NOT NULL
)
SQL

my @fares = (
    ['SVR1', 'Single - Copperline Halt to Millbrook',          950],
    ['RTN1', 'Return - Copperline Halt to Millbrook',         1700],
    ['EXC1', 'Bank-holiday excursion - full line, standard',  2400],
    ['EXCF', 'Bank-holiday excursion - full line, family',    6800],
    ['DIN1', 'Dining car seat - reservation supplement',      1200],
    ['ANN1', 'Annual line member - unlimited travel',        25000],
);
$dbh->do('INSERT INTO fares (code, description, pence) VALUES (?, ?, ?)',
         undef, @$_) for @fares;

print "faredesk db seeded: " . scalar(@fares) . " fares\n";