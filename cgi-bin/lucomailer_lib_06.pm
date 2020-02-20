#!/usr/bin/perl
package lucomailer_lib_06;
# Libreria de funciones para LucoMailer.
#
# Basado en webpay_lib_01.pm
#
# 1.0  - 23/09/2000 - Primera version.
# 1.1  - 23/10/2000 - Inserta blanco despues del signo = para evitar
#                     malas interpretaciones por parte de algunos clientes mail.
# 1.2  - 30/10/2000 - Agrega espacio despues de los signos igual en los mails.

###############################################
# Variables globales.

# $sendmail = '/usr/lib/sendmail'; # Cobalt
$sendmail = '/usr/sbin/sendmail'; # J1
%CONFIG = ();       # Variables del archivo de configuracion.
%FORM = ();         # Variables submitidas en el formulario.
%ROTULOS = ();      # Rotulos de las variables del formulario,
                    # extraidas del archivo de configuracion.

######################################
# Rutinas

#--------------------------------------------------------------------#
# Verifica que el cliente sea unico en algun aspecto, verificando que
# para la columna dada del archivo dado no exista un valor igual a $val.

sub validaUNI {
  my($file,$col,$val) = ($_[0],$_[1],$_[2]);
  my(@linea);
  
  if (-e $file) {
    open(IN,"<$file");
    while (<IN>) {
      @linea = split(/\t/,$_);
      if ($linea[$col] eq $val) { return 0; };
    };
  };
  
  return 1;
  
}; # validaUNI

#--------------------------------------------------------------------#
# Verifica que el cliente sea unico en algun aspecto, verificando que
# para la columna dada del archivo de respaldo no exista un valor igual
# a $val.

sub validaUnico {
  my($nom) = $_[0];
  my($val) = $FORM{$nom}; # El valor es el que viene en el formulario.
  my(@linea) = split(/,/,$CONFIG{'VRFIL'});
  my($col) = 0;
  
  for($i=0; $i<$#linea; $i++) {
    if ($linea[$i] eq $nom) {
      $col = $i + 1; # La columna cero es la fecha (DATE).
      return(&validaUNI($ENV{'DOCUMENT_ROOT'} . '/' . $CONFIG{'REFIL'},$col,$val));
    };
  };
  
  # Si el valor no corresponde, retorna 1.
  return 1;
  
}; # validaUnico

#--------------------------------------------------------------------#
# Escribe linea en archivo de respaldo.

sub writeLine {
  my($file,$line,$caption) = ($_[0],$_[1],$_[2]);
    # Escribe linea en archivo de ordenes.
    if (($file ne '') && ($line ne '') && ($caption ne '')) {
      if (-e $file) {
        open (OUT,">>$file") || die "No pueo abrir [$file] $!\n";
        binmode OUT;
        print OUT "$line\r\n";
        close OUT;
      }else{
        open (OUT,">$file") || die "No pueo abrir [$file] $!\n";
        binmode OUT;
        print OUT "$caption\r\n$line\r\n";
        close OUT;
      };
    };
}; # writeLine

#--------------------------------------------------------------------#
# Borra las lineas indicadas.

sub borraDatos {
  my($archivo) = $_[0];
  my($temp) = "$archivo.temp.txt";
  my($line) = 0;
  
  open (ARCHIVO,"<$archivo") 
      || print "Fail Open file $archivo \n $!\n";

  open (TEMP,">$temp") 
      || print "Fail Open file $temp \n $!\n";

  while (<ARCHIVO>) {
    if ($FORM{"Borra_$line"} ne 'Borrar') {
      print TEMP $_;
    };
    $line++;
  };
   
  close ARCHIVO;
  close TEMP;
  
  unlink $archivo;
  rename $temp, $archivo;
  
  # Si no quedan datos, borra el archivo para facilitar el debug.
  if ($line == 1) { unlink $archivo; };
  
}; # borraDatos

#--------------------------------------------------------------------#
# Entrega tabla con datos del archivo indicado, filtrando los codigos
# totales $cod en base a la lista reducida $dis (identificadores
# separados por comas).

sub getTablaAdmin {
  my($archivo,$cod,$dis) = ($_[0],$_[1],$_[2]);
  my(@data,@ssi,$i,@numbers,$line);
  my($result) = '';
  
  # Elimina espacios, tabs, etc.
  $cod =~ s/[^0-9a-zA-Z\-_,]//sg; 
  $dis =~ s/[^0-9a-zA-Z\-_,]//sg; 

  # Numera campos a desplegar.
  @data = split(/,/,$cod);
  @ssi = split(/,/,$dis);

  foreach $nombre (@ssi) {
    $i = 0;
    while (($data[$i] ne $nombre) && ($i <= $#data)) { $i++; };
    push @numbers,$i;
  };
  
  if (! (-e $archivo)) {
    $result = 'No hay clientes registrados';
    return $result;
  };
  
  open (ARCHIVO,"<$archivo") 
      || die "Fail Open file $archivo \n $!\n";

  $result = '<TABLE BORDER="1" BGCOLOR="#FFFFCC" CELLSPACING="0">' . "\n";
  $line = 0;
  $bold = '<B>';
  while (<ARCHIVO>) {
    @data = split(/\t/,$_);
    $result .= "<TR>\n";
    # $result .= '<TD>' . $bold . $data[0] . '</TD>';
    foreach $num (@numbers) {
      $result .= '<TD>' . $bold . $data[$num] . '</TD>';
    };
    if ($line == 0) {
      $result .= '<TD><B>Borrar</TD>' . "</TR>\n";
      $bold = '';
    }else{
      $result .= '<TD><INPUT TYPE="checkbox" NAME="Borra_' . $line . '" VALUE="Borrar"></TD>' . "</TR>\n";
    };
    $line++;
  };
   
  close ARCHIVO;
  
  $result .= '</TABLE>';
  
  return $result;
  
}; # getTablaAdmin

#--------------------------------------------------------------------#
# Rescata la configuracion desde el archivo config.

sub getConfig {
  my($config) = $_[0];
  my(@pairs,$nom,$cont,$status);
  
  my($buffer) = &readFile($config);
  
  if ($buffer eq '') { &execAbort("903 - No existe archivo de configuracion [$config]."); };
  
  @pairs = split(/[\n\r]/,$buffer);
  $status = 'new';
  foreach $line (@pairs) {
    # Se salta los comentarios.
    next if $line =~ /^#/isg;
    if (($status eq 'new') && ($line =~ /=/g)) {
      ($nom,$cont) = split(/=/,$line);
      $nom =~ s/\W//sg;      # Borra todo lo no alfanumerico.
      if ($nom ne '') {
        if ($cont =~ /'([^']*?)'/g) {
          # Si hay 2 comillas simples, borra todos los espacios por fuera y asigna el valor.
          $cont = $1;
        }elsif ($cont =~ /'/g) {
          # Hay una sola comilla simple, asi que borra espacio por la izquierda,
          # asigna valor y modifica status.
          $cont =~ s/[^']*?'//g;
          $status = 'cont';
        }else{
          # Si no hay comillas simples, borra todos los espacios y asigna el valor.
          $cont =~ s/ //sg;
        };
        $CONFIG{$nom} = $cont;
      };
    }elsif ($status eq 'cont') { # status es 'cont'.
      if ($line =~ /'/sg) {
        # Si no hay comillas simples, asigna la linea completa y continua.
        # Hay una comilla simple, asi que borra espacio por la derecha,
        # asigna valor y modifica status.
        $line =~ s/'[^']*?//mg;
        $status = 'new';
      };
      $CONFIG{$nom} .= "\n$line";
    };
  };
    
}; # getConfig

#--------------------------------------------------------------------#
# Obtiene los rotulos de las variables del formulario.

sub getRotulos {
  my(@lineas) = split(/[\n\r]/,$CONFIG{'ROTUL'});
  foreach $linea (@lineas) {
    if ($linea =~ /\[([^\]]*?)\][^\[]*?\[([^\]]*?)\]/g) {
      $ROTULOS{$1} = $2;
    };
  };
  
}; # getRotulos

#--------------------------------------------------------------------#
# Valida y forma el cuerpo de mail con los campos submitidos.
# $lista es la lista de variables a insertar.
# Usa las variables globales %FORM y %CONFIG.
# No hay que olvidar la variables reservada DATE.
# Retorna el resultado de la validacion, el campo con problemas y el body.

sub formaBody {
  my($lista) = ($_[0]);
  my($name, $value, @claves, $aux, $body, $req, $reb);

  $body = '';
  $req = $CONFIG{'DTREQ'}; # Campos requeridos.
  $reb = $CONFIG{'DTVAL'}; # Campos requeridos blandos.

  @claves = split(/[, \n\r]/,$lista);
  foreach $key (@claves) {
    $key =~ s/[^A-Za-z0-9\-_]//g;
    next if ($key eq '');
    ($name, $value) = ($key, $FORM{$key});
    next if ($name eq '');
    # Campos requeridos (duros y blandos).
    if (($req =~ /\b$name\b/) || (($reb =~ /\b$name\b/) && ($value ne ''))) {
      # print DEBUG "name= [$name] es requerido\n"; # debug
      if ($value eq '') {
        return (0,$name,'');
      }else{
        # Chequea Campo RUT solo si es requerido.
        if ($name =~ /^rut/ig) {
          if (! &chequeaDV($value)) { return (0,$name,'');}; 
        };
        # Chequea email si es requerido.
        if ($name =~ /email/ig) {
          # print DEBUG "name= [$name] es email\n"; # debug
          if (! &chequeaEMail($value)) { return (0,$name,'');}; 
          if ($name eq 'email') { 
            $CONFIG{'FROM'} = $value; # Sustituye remitente.
          };  
        };
        # Verifica que los telefonos y los fax tengan al menos 6 digitos.
        if (($name =~ /fono/ig) || ($name =~ /fax/ig) || ($name =~ /celular/ig)) {
          $aux = $value;
          $aux =~ s/\D//sig; # Borra todo lo no numerico.
          if (length($aux) < 6) { return (0,$name,'');}; 
        };
      }; 
    };
    
    # Elimina no-numeros de los campos RUT.
    if ($name =~ /^rut/ig) {
       $value =~ s/\D//sig;
    };
        
    # Elimina \t del value.
    # $value =~ s/[\t]//sg;
    # Sustituye rets por <BR> en el value.
    # $value = &fixRets($value);
    # $value =~ s/\n/<BR>/sg;
    $name = sprintf '%-20s', $name;
    $body .= $name . ' = ' . $value . "\n";

  };
  
  return (1,'',$body);

}; # formaBody

#--------------------------------------------------------------------#
# Forma la linea a agregar al archivo de respaldo
# de acuerdo a la lista de variables.

sub formaLinea {
 my($lista) = $_[0];
 my($value, @claves, $linea);

  $lista =~ s/[^0-9a-zA-Z\-_,]//sg; # Elimina blancos, retornos de carro, etc.
  @claves = split(/,/,$lista);
  
  foreach $key (@claves) {
    $value = $FORM{$key};
    
    if ($key ne '') {      
      # Elimina \t del value.
      $value =~ s/[\t]//sg;
      # Sustituye rets por <BR> en el value.
      $value = &fixRets($value);
      $value =~ s/\n/<BR>/sg;
      $linea .= "$value\t";
    };

  };
  
  return($linea);
    
}; # formaLinea

#--------------------------------------------------------------------#
# Parsea template para formar body con los datos del %FORM.

sub parseaBody {
my($template,$body) = ($_[0],$_[1]);
my($aux,$valor,$filename);

  # Sustituye el cuerpo principal.
  $template =~ s/%%body%%/$body/sg;
  
  # Sustituye variables del FORM.
  foreach $key (keys %FORM) {
    $aux = $FORM{$key};
    $template =~ s/%%$key%%/$aux/sg;
    # Sustituye inclusiones de archivos.
    while ($template =~ /%%$key:([^:]*?):([^%]*?)%%/) {
      $valor = $1;
      $filename = $2;
      if (($aux =~ /^$valor$/) || ($aux =~ /^$valor,/) || ($aux =~ /,$valor,/) || ($aux =~ /,$valor$/)) {
        $buf2 = &readFile($ENV{'DOCUMENT_ROOT'} . "/$filename");
        $buf2 = &fixRets($buf2);
      }else{
        $buf2 = '';
      };
      $template =~ s/%%$key:$valor:([^%]*?)%%/$buf2/sg;
    };
  };
  
  $template =~ s/%%[^%]*?%%//sg; # Elimina errores.
  
  return $template;
    
}; # parseaBody

#--------------------------------------------------------------------#
# Envia mail.

sub sendMail {
  my($to,$from,$sub,$body) = ($_[0],$_[1],$_[2],$_[3]);
    open(MAIL,"| $sendmail $to") || die "Cant open sendmail $!\n";
    
    print MAIL "To: $to\n";
    print MAIL "Reply-to: $from\n";
    print MAIL "From: $from\n";
    print MAIL "Subject: $sub\n";
    print MAIL "Content-type: text/plain; charset=\"iso-8859-1\"\n";
    print MAIL "Content-Transfer-Encoding: 8bit\n";
    print MAIL "X-Mailer: AltaVoz Mailer\n\n";
    
    print MAIL "$body\n";
    close(MAIL);

}; # sendMail

#--------------------------------------------------------------------#
# Chequea direccion email.
# Si hay problemas retorna 0, si no, 1.

sub chequeaEMail {
  local($eml) = $_[0];

  if (!($eml =~ /\w+\@\w+\.\w+/g )) {
    return 0;
  };
  
  return 1;
}; # chequeaEMail

#--------------------------------------------------------------------#
# Chequea el digito verificador.
# Si hay problemas retorna -1, si no, 0.

sub chequeaDV {
  my($rut) = $_[0];
  
  $rut =~ s/[^0-9Kk]//g; # Elimina todo lo no-numerico.
  
  if ($rut eq '') {
    return 0;
  };
  
  my($dvr,$suma,$mul,$dvi) = (0,0,2,0);
  my($drut) = lc(substr($rut,-1,1));
  $rut = substr($rut,0,(length($rut)-1));
  my(@rut) = split(//,$rut);

  if ( $drut eq 'k' ) {
    $drut = 1;
  };
	
  for ($i= length($rut) -1 ; $i >= 0; $i--) {
    $suma = $suma + $rut[$i] * $mul;
    if ($mul == 7) {
      $mul = 2;
    } else {
      $mul++;
    };
  };

  local($res) = $suma % 11;
  if ($res==1) {
    $dvr = 1;
  } else {
    if ($res == 0) {
      $dvr = 0;
    } else {
      $dvi = 11 - $res;
      $dvr = $dvi;
    };
  };

  if ( $dvr != $drut ) {
    return 0;
  } else {
    return 1;
  };
}; # chequeaDV

#-------------------------------------------------------------------------#
# Lee un archivo por completo. Si el archivo no existe retorna ''.

sub readFile {
  my($archivo) = $_[0];
  my($size) = (-s $archivo);
  my($buffer) = '';
  
  # print "<P>Step fil_1 [$archivo][$size]"; # debug
  if (-e $archivo) {
    open (ARCHIVO,"<$archivo") 
      || print "Fail Open file $archivo \n $!\n";
    binmode ARCHIVO;
    read ARCHIVO,$buffer,$size; 
    close ARCHIVO;
  };
  
  return $buffer;
  
}; # readFile


#-------------------------------------------------------------------------#
# Rescata las variables del chorro (solo modo url-encoded, metodos GET y POST)

sub getFormData {
  my($pair,$buffer,$aux,$sep,$hed,$con,$nom);
  my(@itm);
  
  binmode STDIN;
  
  if ($ENV{'REQUEST_METHOD'} eq 'GET') {
    $buffer = $ENV{'QUERY_STRING'};
  }else{
    read(STDIN, $buffer, $ENV{'CONTENT_LENGTH'});
  };
  
  # Se trata de un formulario "normal" (application/x-www-form-urlencoded).
    
  local(@pairs) = split(/&/, $buffer);
  
  foreach $pair (@pairs) {
    local ($name, $value) = split(/=/, $pair);

    # Un-Webify plus signs and %-encoding
    $value =~ tr/+/ /;
    $value =~ s/%([0-9A-Ha-h]{2})/pack("c",hex($1))/ge;

    # Stop people from using subshells to execute commands
    # Not a big deal when using sendmail, but very important
    # when using UCB mail (aka mailx).
    $value =~ s/~!/ ~!/g;
    
    if ($FORM{$name} eq '') {
      $FORM{$name} = $value;
    }else{
      $FORM{$name} .= ",$value"; # Acumula contenido separado por comas.
    };
    
  };
  
}; # getFormData

#--------------------------------------------------------------------#
# Entrega la fecha y la hora, con ano en formato de dos digitos

sub getDate {
  my($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime(time);
  $mon++;
  $year = $year - 100;
  if (length($year) < 2) { $year = '0' . $year;};
  if (length($mon) < 2) { $mon = '0' . $mon;};
  if (length($mday) < 2) { $mday = '0' . $mday;};
  if (length($hour) < 2) { $hour = '0' . $hour;};
  if (length($min) < 2) { $min = '0' . $min;};
  return "$mday/$mon/$year $hour\:$min";
}; # getDate

#--------------------------------------------------------------------#
# Sustituye retornos de carro para adaptarlos al estilo UNIX.

sub fixRets {
  my($buffer) = $_[0];
  
  $buffer =~ s/\r\n/\n/sg;  # DOS to UNIX
  $buffer =~ s/\r/\n/sg;    # MAC to UNIX
  
  return $buffer;
  
}; # fixRets

#--------------------------------------------------------------------#
# Lee un template y lo parsea insertando en el el mensaje.

sub pagMSG {
  my($tmp,$str) = ($_[0],$_[1]);
  my($buffer);
  
  $buffer = &readFile($tmp);
  
  $buffer =~ s/%%MSG%%/$str/g;
  
  return $buffer;
  
}; # pagMSG

#--------------------------------------------------------------------#
# Aborta el script, entregando un mensaje de error.

sub execAbort {
  my($str) = $_[0];
  print "Content-Type: text/html\n\n";
  print q{
<HTML>
<HEAD>
  <TITLE>Lucomailer - Error de Configuraci&oacute;n</TITLE>
</HEAD>
<BODY BGCOLOR="#ffffff">

<P><CENTER>&nbsp;</CENTER></P>

<P><CENTER><B><FONT COLOR="#FF0000" SIZE=+2>
  };
  if ($str eq '') {
    print 'Error de Configuraci&oacute;n';
  }else{
    print $str;
  };
  print '</FONT></B></CENTER></P></BODY></HTML>';
  exit;
}; # execAbort

#--------------------------------------------------------------------#
# Prueba que el request provenga de alguno de los servidores permitidos.

sub testServers {
  my($referer) = $_[0];
  my(@server) = split(/,/,$CONFIG{'SRVER'});
  
  foreach $server (@server) {
    if (($referer =~ /^http:\/\/$server\//g) || ($referer =~ /^https:\/\/$server\//g)) {
      return; # El request proviene de un server habilitado.
    };
  };
  # El request no proviene de ningun server habilitado.
  &execAbort("950 - Error en los datos enviados [$referer].");

}; # testServers

#-------------------------------------------------------------------#
# Detecta existencia de archivo $LOCK_FILE. Si existe, espera hasta 10 segundos,
# si sigue existiendo, lo borra y lo crea de nuevo.

sub lockDetect {
  my($lock_file) = $_[0];
  my($tiempo) = time;
  
  do { sleep(1); } until ((!(-e $lock_file)) || ((time - $tiempo) > 10));
  
  open (OUT, ">$lock_file");
  print OUT 'xxx';
  close OUT;

}; # lockDetect

#-------------------------------------------------------------------#
# Borra el archivo $LOCK_FILE para permitir la ejecucion de otras
# instancias.

sub lockRemove {
  my($lock_file) = $_[0];
  unlink $lock_file;
}; # lockRemove

#--------------------------------------------------------------------#
# Escribe una linea en el archivo de debug.

sub debug {

  # open (DEBUG,">>$CPANDIR/$DEBUG_FILE");
  # print DEBUG $_[0] . "\n";
  # close DEBUG;

}; # debug


return 1;

