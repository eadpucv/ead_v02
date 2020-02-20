#!/usr/bin/perl
# Script de administracion de LucoMailer 6.
#
# 1.0  - 23/09/2000 - Primera version.
# 1.1  - 25/09/2000 - Incorpora deteccion automatica del directorio de la cgi,
#                     para facil localizacion fuera del directorio raiz.

###############################################
# Inicializaciones varias.

# print "Content-Type: text/plain\n\n"; # debug

my($ROOTDIR) = $ENV{'DOCUMENT_ROOT'};  # Ubicacion del directorio raiz de esta seccion.
my($REFERER) = $ENV{'HTTP_REFERER'};   # Pagina de origen del requerimiento.
my($SRV_NAM) = $ENV{'SERVER_NAME'};    # Nombre del servidor.

my($SCRIPTROOT) = $ENV{'SCRIPT_FILENAME'};
$SCRIPTROOT =~ s/\/([^\/]*)$//g;       # 1.1 Elimina nombre del archivo.
use lib $SCRIPTROOT;
use lucomailer_lib_06;

my($PATH) = $REFERER;
$PATH =~ s/\/([^\/]*)$//g;         # Borra todo despues del ultimo slash.
$FORMNAME = $1;
$FORMNAME =~ s/\.[^\.]*$//g;       # Extrae la extension.
$PATH =~ s/^[^\/]*\/\/[^\/]+\///g; # Borra todo antes del primer slash.

my($template,$tabla);

######################################
# Main

# Rescata variables del chorro.
&lucomailer_lib_06::getFormData();
$ACCI = $lucomailer_lib_06::FORM{'ACCI'};
$CFG  = $ROOTDIR . '/' . $lucomailer_lib_06::FORM{'CFG'};

# Lee archivo de configuracion correspondiente a esta linea.
&lucomailer_lib_06::getConfig($CFG);

&lucomailer_lib_06::testServers($REFERER);

if ($ACCI eq 'Lista') {
  &showTable();
  
}elsif ($ACCI eq 'Borrar') {
  &lucomailer_lib_06::borraDatos("$ROOTDIR/" . $lucomailer_lib_06::CONFIG{'REFIL'});
  &showTable();
  
}else{
  &lucomailer_lib_06::execAbort("972 - Error en los datos enviados [$ACCI].");
};
  

######################################
# Rutinas

#--------------------------------------------------------------------#
# Despliega datos del archivo de pagos.

sub showTable {
  $template = &lucomailer_lib_06::readFile("$ROOTDIR/" . $lucomailer_lib_06::CONFIG{'TMPAD'});
  $tabla = &lucomailer_lib_06::getTablaAdmin("$ROOTDIR/" . $lucomailer_lib_06::CONFIG{'REFIL'},
                                         $lucomailer_lib_06::CONFIG{'VRFIL'},
                                         $lucomailer_lib_06::CONFIG{'VRLIS'});
  $template =~ s/%%TABLA%%/$tabla/sg;
  print "Content-Type: text/html\n\n$template";
}; # showTable

