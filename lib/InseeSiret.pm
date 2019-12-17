package InseeSiret {
 use Modern::Perl ;
 use Carp;
 use WWW::Curl::Easy;
 use Moose;
 use POSIX qw(strftime);
 use Data::Dumper;
 use FindBin;
 use lib "$FindBin::Bin/./";
 use ExInseeCurl;

=pod

=head1 Class InseeSiret.pm
	This class connect to the SIREN API
	Gets the response for a SIREN number

=head2 Attributes:

=over 5

=item user defines the user for the connection

=item consKey defined by the API 

=item secKey secret key of the account 

=item date 

=back
 
=cut

 # Attributes
 has 'user' , is => 'ro', isa => 'Str';
 has 'consKey', is => 'ro', isa => 'Str';
 has 'secKey', is => 'ro', isa => 'Str';
 has 'token', is => 'ro', isa => 'Str', writer => '_set_token';
 has 'date', is=> 'ro', isa => 'Str', default => strftime( "%F", localtime);

 #Methods
 
=pod 

=head1 Method get_token
	This method get the token to identify the session

=cut

sub get_token {
my  $self = shift ;
my $url = "https://api.insee.fr/token";
my $curl = WWW::Curl::Easy->new;
my $param= "grant_type=client_credentials&validity_period=604800";

$curl->setopt(CURLOPT_HEADER,1);
$curl->setopt(CURLOPT_URL, $url);
$curl->setopt(CURLOPT_CUSTOMREQUEST, "POST");
$curl->setopt(CURLOPT_POSTFIELDS, $param );

$curl->setopt(CURLOPT_USERNAME, $self->consKey );
$curl->setopt(CURLOPT_PASSWORD, $self->secKey );
# A filehandle, reference to a scalar or reference to a typeglob can be used here.
my $response_body;
$curl->setopt(CURLOPT_WRITEDATA,\$response_body);
# Starts the actual request
my $retcode = $curl->perform;

# Looking at the results...
if ($retcode == 0) {
        my $response_code = $curl->getinfo(CURLINFO_HTTP_CODE);
        # judge result and next action based on $response_code
		if ( $response_code == 200 ){
        	my ( $responseNew ) = $response_body =~ /"access_token":"(\S*)","scope/ ;
			$self->_set_token( $responseNew);
		} else {	
			print "$response_code \n";
			ExInseeCurl->throw({ 
				code => $response_code,
				method => 'revoke_Token'
			} );							
		}
        my ( $responseNew ) = $response_body =~ /"access_token":"(\S*)","scope/ ;
#        print "\n $responseNew \n";
		$self->_set_token( $responseNew);
	} else {
        # Error code, type of error, error message
		#TODO implement exception
        print("An error happened: $retcode ".$curl->strerror($retcode)." ".$curl->errbuf."\n");
	}
}

=pod

=head1 revoke_token
	This method is revoquing the token 

=cut

sub revoke_token {
my $self = shift ;
my $url = "https://api.insee.fr/revoke";
my $curl = WWW::Curl::Easy->new;
my $token = $self->token ;
my $user = $self->user;
my $consKey = $self->consKey;
my $secKey = $self->secKey;
my $param= "token={$token}";

$curl->setopt(CURLOPT_HEADER,1);
$curl->setopt(CURLOPT_URL, $url);
$curl->setopt(CURLOPT_CUSTOMREQUEST, "POST");
$curl->setopt(CURLOPT_POSTFIELDS, $param );

$curl->setopt(CURLOPT_USERNAME, $consKey );
$curl->setopt(CURLOPT_PASSWORD, $secKey );
my $response_body;
$curl->setopt(CURLOPT_WRITEDATA,\$response_body);
# Starts the actual request
my $retcode = $curl->perform;

# Looking at the results...
if ($retcode == 0) {
        my $response_code = $curl->getinfo(CURLINFO_HTTP_CODE);
        # judge result and next action based on $response_code
        if ( $response_code != 200 ){
			print "$response_code \n";
			ExInseeCurl->throw({ 
				code => $response_code,
				method => 'get_Token'
			} );							
		}
	} else {
		#TODO implement exception
        # Error code, type of error, error message
        carp("An error happened: $retcode ".$curl->strerror($retcode)." ".$curl->errbuf."\n");
	}
}

=pod

=head1 Method response
	This method provides the response from the API
	to get the details of all the etablissements

=head2 Attributes

=over 3

=item C<$siren> defines the SIREN for which the search processed 

=item C<$date> defines the period for which the search is processsed

=back

=cut

sub response {
	my $self = shift;
	my $siren = shift ;
	my $date = $self->date ;
# A check should be done on the SIREN number
#
	my $query = "siren:$siren&date=$date";
# &periode(etatAdministratifEtablissement:A)
	my $url = "https://api.insee.fr/entreprises/sirene/V3/siret?q=";
	$url .= $query ;
	my $curl = WWW::Curl::Easy->new;
	my $token = $self->token;
	my @headers = ("Accept: application/json","Authorization: Bearer $token");
	$curl->setopt(CURLOPT_HEADER,1);
	$curl->setopt(CURLOPT_URL, $url);
	$curl->setopt(CURLOPT_CUSTOMREQUEST, "GET");
	$curl->setopt(CURLOPT_HTTPGET, 1 );
	$curl->setopt(CURLOPT_HTTPHEADER, \@headers);
# A filehandle, reference to a scalar or reference to a typeglob can be used here.
	my $response_body;
	$curl->setopt(CURLOPT_WRITEDATA,\$response_body);
# Starts the actual request
	my $retcode = $curl->perform;
# Looking at the results...
	if ($retcode == 0) {
    	    my $response_code = $curl->getinfo(CURLINFO_HTTP_CODE);
        	# judge result and next action based on $response_code
        	if ( $response_code == 200 ){
				#			my %result = $self->format_body( $response_body, $formatRef, $regex, $siren  );
				# 
				return $response_body ;
			} else {
				print "$response_code \n";
				ExInseeCurl->throw({ 
					code => $response_code,
					method => 'getSiret'
				} );							
			} 
		}else {
		#TODO  implement exception
        # Error code, type of error, error message
		#    carp("An error happened: $retcode ".$curl->strerror($retcode)." ".$curl->errbuf."\n");
		#}
		}
	}

=pod	

=head1 Method get_vat
	This method calculates the VAT number from the SIREN

=head2 Attributes

=over 2

=item C<$siren> siren number

=back	

=cut

sub get_vat {
	my ($self, $siren ) = @_ ;
	my $modulo = (12 + ( 3 * ( $siren % 97)) %97) ;
	my $vat = "FR$modulo$siren" ;
	return $vat ;
		}
1;
}
