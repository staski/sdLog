#!/usr/bin/perl

#use POSIX; # for floor etc.
use CGI;
use CGI::Carp qw ( fatalsToBrowser );
use Getopt::Long;

$CGI::POST_MAX=1024 * 512;
my $airportDirectory ="world-airports.csv";

GetOptions ("airportDir=s" => \$airportDirectory,
    "pilot=s" => \$pilot,
    "climode=s" => \$climode,
    "debug=s" => \$debug);


#$debug = 1;
$query = CGI->new;
$pilot = $query->param('pilot');

readAirportDirectory();


if (!defined($climode)){
    print   $query->header,
            $query->start_html;

    $lfh  = $query->upload('theFile');
    if (defined $lfh) {
        # Upgrade the handle to one compatible with IO::Handle:
        my $io_handle = $lfh->handle;

        open(OUTFILE, ">tmpFile") ;
        while ($bytesread = read($io_handle, $buffer, 1024)) {
            print OUTFILE $buffer;
        }
        close OUTFILE;
    }
    $flightlog = "tmpFile";
        print "<br>";
} else {
    $flightlog = $ARGV[0];
}

print "Date; Pilot; Plane; FROM; TO; Start; Duration\n";

if (!defined($climode)){
    open(FLIGHTLOG, "<", "tmpFile") || die "cant open INSTREAM: $!";
} else {
    open(FLIGHTLOG, "$flightlog" ) || die "can't open flightlog file $flightlog: $!";
}

while (<FLIGHTLOG>){
    
    if (/^\(.+ nm\) (.+)/){
        $_= $1;
    }
    @logline = split(/\t/);
    for ($i = 0; $i < $#logline; $i++){
        
        #print "$i $logline[$i]|";
    }
    #print "\n";
    #next;
    next unless $logline[0] =~ /^\w/;
    if ($logline[4] =~/nm/){
        ($fromto, $takeoff, $duration, $landing, $distance,$blocktime,$enginetime) = @logline;
        $plane = "Unknown";
    } elsif ($logline[5] =~/nm/){
        ($fromto, $plane, $takeoff, $duration, $landing, $distance,$blocktime,$enginetime) = @logline;
    } elsif ($logline[3] =~/nm/){
        ($fromto, $duration, $landing, $distance,$blocktime,$enginetime) = @logline;
        if ($fromto =~ /([^2]+)(2018\/\d\d\/\d\d \d\d:\d\d)/){
            $fromto = $1;
            $takeoff = $2;
            $fromto =~ s/ *$//;
            $plane = "Unknown";
        }
    }
    
    else {
        next;
    }

    ($from, $to) = split (/ - /, $fromto);
    $fromICAO = getICAO($from);
    $toICAO = getICAO($to);
    
    next if ($from eq "Unknown");
    ($date,$time) = split(/ /,$takeoff);
    $date =~ s/\//-/g;
    $dmins = 0;
    if ($duration =~ /(\d) hr (\d+) m/){
        $dmins = $1 * 60 + $2;
    } elsif ($duration =~ /(\d+) min/) {
        $dmins = $1;
    }
    next unless $dmins > 5;
    if (!defined($climode)){
        print "<br>";
    }
    print "$date $time;$pilot;$plane;$fromICAO;$toICAO;$date $time;$dmins\n";
}

close OUTFILE;

if (!defined($climode)){
    unlink "tmpFile";
    print $query->end_html;
}

sub readAirportDirectory {
    open (ALLAIRPORTS, "<$airportDirectory" ) || die "can't open file $airportDirectory: $!";

    @firstLine = split(/,/, <ALLAIRPORTS>);
    $tabsize = $#firstLine + 1;

    for ($i=0; $i <= $#firstLine; $i++){
        $firstLine[$i] =~ /(\w+)\((.*)\)/;
        $column[$i] = $1;
        $unit[$i] = $2;
    }

    while (<ALLAIRPORTS>)
    {
        @airportLine = split (/,/);
    
        $ICAO = $airportLine[1];
        $ap_name = $airportLine[3];
        $p_name = trimName($ap_name);
        $p_name = normalizeName($p_name);
        $ICAO{$p_name}  = $ICAO;
    }
}

sub getICAO {
    my $name = shift;
    my $dashname = normalizeName($name);
    return $ICAO{$name} || $ICAO{$dashname} ||  "$name";
}

#strip off any decoration in the name of the world airport database
sub trimName {
    my $name = shift;
    $name =~ s/"(.*)"/$1/;
    $name =~ s/ Airport//;
    $name =~ s/ Heliport//;
    $name =~ s/ Airfield//;
    $name =~ s/Flugplatz //;
    $name =~ s/Airport //;
    return $name;
}

#remove any ambiguos spelling options
sub normalizeName {
    my $name = shift;
    $name =~ s/ä/ae/g;
    $name =~ s/ü/ue/g;
    $name =~ s/ö/oe/g;
    $name =~ s/ß/ss/g;
    $name =~ s/é/e/g;
    $name =~ s/-//g;
    $name =~ s/ //g;
    return $name;
}

sub printUsageAndExit(){
	print "exit now ARGV = $#ARGV\n";
	exit(0);
}
