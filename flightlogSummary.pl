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

readAirportDirectory();


if (!defined($climode)){
    $query = CGI->new;
    $pilot = $query->param('pilot');
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
    my $validline = 0;
    my $toindex = 0;
    my $toend = 0;
    my $plane ="Unknown";
    my $takeoff = "";
    my $duration = "";
    
    my $from = ""; my $to = "";
    @logline = split(/\s/);
    next unless $logline[0] =~ /^\w/;

    for ($i = 0; $i < $#logline; $i++){
        if ($logline[$i] eq "-"){
            $toindex = $i + 1;
            for ($j = 0; $j < $i; $j++){
                print "$j $logline[$j] " if $debug;
                $from .= $logline[$j];
            }
            print "\n FROM $from \n" if $debug;
        }
        if ($logline[$i] =~ /(20\d\d\/\d\d\/\d\d)/ && ($toindex > 0) && $to eq ""){
            $validline = 1;
            $date = $1;
            my $toend = $i;
            if (isAircraft($logline[$i-1]) == 1){
                $toend = $i -1;
                $plane = $logline[$i - 1];
                print "$i $plane " if $debug;
            }

            for (my $j = $toindex; $j < $toend; $j++){
                print "$j $logline[$j] " if $debug;
                $to .= $logline[$j];
            }
            print "\n TO $to \n" if $debug;

            if ($logline[$i + 1] =~ /(\d\d:\d\d)/){
                $takeoff = $date . " " . $1;
                print "TAKEOFF $takeoff\n" if $debug;
            }
        }
        if ($logline[$i] eq "hr"){
            print "$i $logline[$i] " if $debug;
            $duration .= $logline[$i - 1] . " hr ";
        }
        if ($logline[$i] eq "min"){
            print "$i $logline[$i] " if $debug;
            $duration .= $logline[$i - 1] . " min";
            print "DURATION $duration\n" if $debug;
        }
        if ($logline[$i] eq "m"){
            print "$i $logline[$i] " if $debug;
            $duration .= $logline[$i - 1] . " m";
            print "DURATION $duration\n" if $debug;
        }
    }

#    if ($logline[4] =~/nm/){
#        ($fromto, $takeoff, $duration, $landing, $distance,$blocktime,$enginetime) = @logline;
#        $plane = "Unknown";
#    } elsif ($logline[5] =~/nm/){
#        ($fromto, $plane, $takeoff, $duration, $landing, $distance,$blocktime,$enginetime) = @logline;
#    } elsif ($logline[3] =~/nm/){
#        ($fromto, $duration, $landing, $distance,$blocktime,$enginetime) = @logline;
#        if ($fromto =~ /([^2]+)(2018\/\d\d\/\d\d \d\d:\d\d)/){
#            $fromto = $1;
#            $takeoff = $2;
#            $fromto =~ s/ *$//;
#            $plane = "Unknown";
#        }
#    }
    
    next unless $validline == 1;
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

sub isAircraft {
    my $airplane = shift;
    $airplane = lc $airplane;
    if ($airplane eq "unknown"){
        return 1;
    }
    if (length $airplane == 5 && $airplane =~ /^de/){
        return 1;
    }
    return 0;
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
    $name =~ s/Aviosuperficie //;
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
    $name =~s/\///g;
    $name = lc($name);
    return $name;
}

sub printUsageAndExit(){
	print "exit now ARGV = $#ARGV\n";
	exit(0);
}
