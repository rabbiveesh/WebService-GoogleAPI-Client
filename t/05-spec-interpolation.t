use strict;
use warnings;
use Test::More;
use Cwd;

use WebService::GoogleAPI::Client;

my $dir   = getcwd;
my $DEBUG = $ENV{GAPI_DEBUG_LEVEL} || 0;        ## to see noise of class debugging
my $default_file = $ENV{ 'GOOGLE_TOKENSFILE' } || "$dir/../../gapi.json";    ## assumes running in a sub of the build dir by dzil
$default_file = "$dir/../gapi.json" unless -e $default_file;                 ## if file doesn't exist try one level up ( allows to run directly from t/ if gapi.json in parent dir )

#if running from root of the repo, grab the one from the t/ directory
$default_file = "$dir/t/gapi.json" unless -e $default_file;

plan skip_all => 'No service configuration - set $ENV{GOOGLE_TOKENSFILE} or create gapi.json in dzil source root directory'  unless -e $default_file;

ok( my $gapi = WebService::GoogleAPI::Client->new( debug => $DEBUG, gapi_json => $default_file ), 'Creating test session instance of WebService::GoogleAPI::Client' );

my $options = {
  api_endpoint_id => 'drive.files.list',
  options => {
    fields => 'files(id,name,parents)'
  }
};

$gapi->_process_params_for_api_endpoint_and_return_errors($options);

is $options->{path}, 
'https://www.googleapis.com/drive/v3/files?fields=files%28id%2Cname%2Cparents%29',
'Can interpolate globally available query parameters';

#TODO- make a test for a default param that should go into the
#query, like 'fields'.
$options = {
  api_endpoint_id => "sheets:v4.spreadsheets.values.update",  
  options => { 
    spreadsheetId => 'sner',
    includeValuesInResponse => 'true',
    valueInputOption => 'RAW',
    range => 'Sheet1!A1:A2',
    'values' => [[99],[98]]
  },
  cb_method_discovery_modify => sub { 
    my  $meth_spec  = shift; 
    $meth_spec->{parameters}{valueInputOption}{location} = 'path';
    $meth_spec->{path} .= "?valueInputOption={valueInputOption}";
    return $meth_spec;
  }
};

$gapi->_process_params_for_api_endpoint_and_return_errors($options);

is $options->{path}, 'https://sheets.googleapis.com/v4/spreadsheets/sner/values/Sheet1!A1:A2?valueInputOption=RAW&includeValuesInResponse=true', 
'interpolation works with user fiddled path, too';

subtest 'Testing {+param} type interpolation options' => sub {
      plan skip_all => <<MSG
Need access to the scope https://www.googleapis.com/auth/jobs  
or https://www.googleapis.com/auth/cloud-platform
MSG
    unless $gapi->has_scope_to_access_api_endpoint('jobs.projects.jobs.delete');

  my $interpolated = 'https://jobs.googleapis.com/v3/projects/sner/jobs';

  $options = { api_endpoint_id => 'jobs.projects.jobs.delete',
    options => {name => 'projects/sner/jobs/bler'} };
  $gapi->_process_params_for_api_endpoint_and_return_errors( $options );
  is $options->{path}, "$interpolated/bler", 
    'Interpolates a {+param} that matches the spec pattern';

  $options = 
  { api_endpoint_id => 'jobs.projects.jobs.list',
    options => { parent => 'sner' } };
  $gapi->_process_params_for_api_endpoint_and_return_errors( $options );
  is $options->{path}, $interpolated, 
    'Interpolates just the dynamic part of the {+param}, when not matching the spec pattern';

  $options = 
  { api_endpoint_id => 'jobs.projects.jobs.delete',
    options => {projectsId => 'sner', jobsId => 'bler'} };
  $gapi->_process_params_for_api_endpoint_and_return_errors( $options );

  is $options->{path}, "$interpolated/bler", 
    'Interpolates params that match the flatName spec (camelCase)';

  $options = 
  { api_endpoint_id => 'jobs.projects.jobs.delete',
    options => {projects_id => 'sner', jobs_id => 'bler'} };
  $gapi->_process_params_for_api_endpoint_and_return_errors( $options );

  is $options->{path}, "$interpolated/bler", 
    'Interpolates params that match the names in the api description (snake_case)';


};

my @errors;
subtest 'Checking for proper failure with {+params} in unsupported ways' => sub {
    plan skip_all => <<MSG
Need access to the scope https://www.googleapis.com/auth/jobs 
or https://www.googleapis.com/auth/cloud-platform
MSG
    unless $gapi->has_scope_to_access_api_endpoint('jobs.projects.jobs.delete');


    $options = 
    { api_endpoint_id => 'jobs.projects.jobs.delete',
      options => { name => 'sner' } };
    @errors = $gapi->_process_params_for_api_endpoint_and_return_errors( $options );
    is $errors[0], 'Not enough parameters given for {+name}.', 
      "Fails if you don't supply enough values to fill the dynamic parts of {+param}";

    $options = 
    { api_endpoint_id => 'jobs.projects.jobs.delete',
      options => { jobsId => 'sner' } };
    @errors = $gapi->_process_params_for_api_endpoint_and_return_errors( $options );
    is $errors[0], 'Missing a parameter for {projectsId}.', 
      "Fails if you don't supply enough values to fill the flatPath";

};






done_testing;