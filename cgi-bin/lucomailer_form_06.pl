#!/usr/bin/perl
# Script de recepcion de formularios.
#
# 1.0  - 23/09/2000 - Primera version.
# 1.1  - 25/09/2000 - Incorpora deteccion automatica del directorio de la cgi,
#                     para facil localizacion fuera del directorio raiz.
# 1.2  - 30/09/2000 - Permite el envio a mas de un administrador.
# 1.3  - 30/10/2000 - Corrige bug de cuando el formulario esta en la raiz del sitio.

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
# $PATH =~ s/^[^\/]*\/\/[^\/]+\///g; # Borra todo antes del primer slash.
$PATH =~ s/^[^\/]*\/\/[^\/]*\/*//g; # 1.3 Borra todo antes del primer slash.

my($IDTC,$CAMPO,$location,$mensaje);

######################################
# Main

# Rescata variables del chorro.
&lucomailer_lib_06::getFormData(); 

$DATE = &lucomailer_lib_06::getDate();       # Agrega TimeStamp.
$lucomailer_lib_06::FORM{'DATE'} = $DATE;

# print "FORMNAME: $FORMNAME\n"; # debug

# Lee archivo de configuracion.
if (-e "$ROOTDIR/$PATH/$FORMNAME\.cfg") {
  &lucomailer_lib_06::getConfig("$ROOTDIR/$PATH/$FORMNAME\.cfg");
}elsif (-e "$ROOTDIR/cpan/$FORMNAME/$FORMNAME\.cfg") {
  &lucomailer_lib_06::getConfig("$ROOTDIR/cpan/$FORMNAME/$FORMNAME\.cfg");
}else{
  &lucomailer_lib_06::execAbort("903 - No existe archivo de configuracion<BR>[$ROOTDIR/$PATH/$FORMNAME\.cfg]<BR>[$ROOTDIR/cpan/$FORMNAME/$FORMNAME\.cfg].");
};

# foreach $key (keys %lucomailer_lib_06::CONFIG) { print "$key = $lucomailer_lib_06::CONFIG{$key}\n"; }; # debug

&lucomailer_lib_06::testServers($REFERER);

# Sustituye variables de configuracion.
&sustituyeVars();

# Procesa el formulario.
&procesaForm();

######################################
# Rutinas

#--------------------------------------------------------------------#
# Sustituye variables de configuracion.

sub sustituyeVars {
  if ($lucomailer_lib_06::FORM{'ADMIN'} ne '') {
    $lucomailer_lib_06::CONFIG{'ADMIN'} = $lucomailer_lib_06::FORM{'ADMIN'};
  };
  if ($lucomailer_lib_06::FORM{'SBADM'} ne '') {
    $lucomailer_lib_06::CONFIG{'SBADM'} = $lucomailer_lib_06::FORM{'SBADM'};
  };
  if ($lucomailer_lib_06::FORM{'SBCLI'} ne '') {
    $lucomailer_lib_06::CONFIG{'SBCLI'} = $lucomailer_lib_06::FORM{'SBCLI'};
  };
}; # sustituyeVars


#--------------------------------------------------------------------#
# Procesa el formulario.

sub procesaForm {
  my($mensaje,$linea,$caption,@destinos);
  my(@unicos) = split(/,/,$lucomailer_lib_06::CONFIG{'DTUNI'});
  
  # Valida campos unicos.
  if ($lucomailer_lib_06::CONFIG{'REFIL'} ne '') {
    foreach $unico (@unicos) {
      if (! &lucomailer_lib_06::validaUnico($unico)) {
        # Entrega pagina de falla.
        $mensaje = $lucomailer_lib_06::CONFIG{'MSUNI'};
        # Sustituye campos del FORM.
        $mensaje = &lucomailer_lib_06::parseaBody($mensaje,'') . " [$unico]";
        print "Content-Type: text/html\n\n";
        print &lucomailer_lib_06::pagMSG("$ROOTDIR/" . $lucomailer_lib_06::CONFIG{'TMPRE'},$mensaje);
        return;
      };
    };
  };
  
  my($ok,$val,$body) = &lucomailer_lib_06::formaBody($lucomailer_lib_06::CONFIG{'VRMAI'});
  
  if ($ok) {
  
    # Escribe linea en archivo de respaldo si es que corresponde hacerlo.
    if ($lucomailer_lib_06::CONFIG{'REFIL'} ne '') {
      $linea = $DATE . "\t" . &lucomailer_lib_06::formaLinea($lucomailer_lib_06::CONFIG{'VRFIL'});
      $caption = $lucomailer_lib_06::CONFIG{'VRFIL'};
      $caption =~ s/[^0-9a-zA-Z\-_,]//sg; # Elimina blancos, retornos de carro, etc.
      $caption =~ s/,/\t/sg;              # Cambia comas por tabuladores.
      $caption = 'Fecha' . "\t" . $caption;
      # Escribe linea en archivo de respaldo.
      &lucomailer_lib_06::writeLine("$ROOTDIR/" . $lucomailer_lib_06::CONFIG{'REFIL'},
                                    $linea,
                                    $caption);
    };
    
    # Envia mail al (los) administrador (es).
    $body = &lucomailer_lib_06::parseaBody($lucomailer_lib_06::CONFIG{'BDADM'},$body);
    @destinos = split(/,/,$lucomailer_lib_06::CONFIG{'ADMIN'}); # 1.1
    foreach $destino (@destinos) {
      &lucomailer_lib_06::sendMail($destino,
                                   $lucomailer_lib_06::CONFIG{'FROM'},
                                   $lucomailer_lib_06::CONFIG{'SBADM'},
                                   $body); 
    };
    # print "Content-Type: text/html\n\n";
    # $mensaje = "[$body]";
    # print &lucomailer_lib_06::pagMSG("$ROOTDIR/" . $lucomailer_lib_06::CONFIG{'TMPRE'},$mensaje);
    # return;
    
    # Envia mail de auto respuesta.
    if ( &lucomailer_lib_06::chequeaEMail($lucomailer_lib_06::FORM{'email'})
         && ($lucomailer_lib_06::CONFIG{'BDCLI'} ne '') ) {
      $body = &lucomailer_lib_06::parseaBody($lucomailer_lib_06::CONFIG{'BDCLI'},'');
      &lucomailer_lib_06::sendMail($lucomailer_lib_06::FORM{'email'},
                                   $lucomailer_lib_06::CONFIG{'ADMIN'},
                                   $lucomailer_lib_06::CONFIG{'SBCLI'},
                                   $body); 
    };
    $mensaje = $lucomailer_lib_06::CONFIG{'MSGRA'};
    $mensaje = &lucomailer_lib_06::parseaBody($mensaje,''); # . '[' . $lucomailer_lib_06::CONFIG{'ADMIN'} . ']';
    print "Content-Type: text/html\n\n";
    print &lucomailer_lib_06::pagMSG("$ROOTDIR/" . $lucomailer_lib_06::CONFIG{'TMPRE'},$mensaje);
  }else{
    # Entrega pagina de falla.
    &lucomailer_lib_06::getRotulos();
    if ($lucomailer_lib_06::ROTULOS{$val} ne '') { $val = $lucomailer_lib_06::ROTULOS{$val}; };
    $mensaje = $lucomailer_lib_06::CONFIG{'MSFAI'};
    # Sustituye campo fallado.
    $mensaje =~ s/%%CAMPO%%/$val/sg;
    # Sustituye campos del FORM.
    $mensaje = &lucomailer_lib_06::parseaBody($mensaje,'');
    print "Content-Type: text/html\n\n";
    print &lucomailer_lib_06::pagMSG("$ROOTDIR/" . $lucomailer_lib_06::CONFIG{'TMPRE'},$mensaje);
  };
}; # procesaForm

