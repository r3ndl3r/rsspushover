package RSSDBI;
use strict;
use warnings;

use DBI;
use POSIX qw(strftime);
use Exporter qw(import);

our @EXPORT = qw( getItems getFeeds inItem log addFeed delFeed liFeeds dob );

my %attr = ( PrintError => 0, RaiseError => 1 );
my ($logf, $dsn, $dbh);


sub new {
    my ($class, %args) = @_;
    my %auth;

    open AUTH, $args{dbauth} or RSSDBI::log("Couldn't open $args{dbiauth}: $!\n") && die $!;
    
    while (<AUTH>) {
        chomp;
        s/\s//g;
        my ($key, $value) = split /=/, $_;
        if ($key =~ /^user(name)?$/i) {
            $auth{dbUser} = $value;
        } elsif ($key =~ /^pass(word)?$/i) {
            $auth{dbPass} = $value;
        }
    }

    $dsn = "DBI:MariaDB:$args{table}";
    $dbh = DBI->connect($dsn, $auth{dbUser}, $auth{dbPass}, \%attr) or die $!;

    if ($args{log}) {
        open $logf, '>>', $args{log} or die "Couldn't open logfile: $!\n";
    }

    return bless \%args, $class;
}


sub log {
    my ($self, $log) = @_;

    return 1 if !$log;

    printf $logf "[%s] %s\n", 
           strftime('%d/%m/%y %H:%M:%S', localtime),
           $log;
}


sub inItem {
    my ($self, $link, $title) = @_;
    my $sth = $dbh->prepare(
            "INSERT INTO items(link,title) VALUES(?,?)"
            );
    $sth->execute($link, $title);
}


sub getItems {
    my ($self, $link, $title) = @_;
    my $sth = $dbh->prepare(
            "SELECT * FROM items WHERE link = ? AND title = ?"
            );
    $sth->execute($link, $title);

    return $sth->fetchrow_array();
}


sub pushOver {
    my ($self, $message, $push) = @_;

    return 1 if !$push;

    $self->log("Pushing new item to mobile devices.");

    my $sth = $dbh->prepare(
            "SELECT * FROM pushover"
            );
    $sth->execute();

    my $pushOver = $sth->fetchrow_hashref();

    my $ua = LWP::UserAgent->new();
    my $res = $ua->post(
            'https://api.pushover.net/1/messages.json',
            [ 
            token => $pushOver->{token},
            user => $pushOver->{user},
            message => $message
            ] );

    if ($res->is_success) {
        $self->log("SUCCESS!");
    } else {
        $self->log("FAILED: ".$res->status_line);
    }

    return $res->is_success;

}


sub getFeeds {
    my $sth = $dbh->prepare(
            "SELECT * FROM links"
            );
    $sth->execute;

    my @sqlLinks;
    while (my $foo = $sth->fetchrow_array()){
        push @sqlLinks, $foo;
    }

    return @sqlLinks;

}


sub addFeed {
    my ($self, $add) = @_;
    my $sth = $dbh->prepare(
            "INSERT INTO links(link) VALUES(?)
            ");
    $sth->execute($add);
}


sub delFeed {
    my ($self, $delLink) = @_;
    my $sth = $dbh->prepare("DELETE FROM links WHERE link = ?");
    $sth->execute($delLink);

    $sth = $dbh->prepare("DELETE FROM items WHERE link = ?");
    $sth->execute($delLink);

    print "REMOVED $delLink\n";
}


sub liFeeds {
    my ($self, $i) = shift;

    printf "[%s] %s\n", ++$i, $_ for $self->getFeeds();
}


1;
