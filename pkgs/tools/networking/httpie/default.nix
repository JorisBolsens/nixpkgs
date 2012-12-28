{ stdenv, fetchurl, buildPythonPackage }:

buildPythonPackage {
  name = "httpie-0.3.1";
  namePrefix = "";

  src = fetchurl {
    url = "http://pypi.python.org/packages/source/h/httpie/httpie-0.3.1.tar.gz";
    sha256 = "0abjkwcirmp6qa190qgbgj5fmmkmk5aa3fdiyayl2indh6304x7a";
  };

  doCheck = false;

  meta = {
    description = "HTTPie is a command line HTTP client whose goal is to make CLI human-friendly.";
    homepage = http://httpie.org/;
    license = "BSD";
    maintainers = [ stdenv.lib.maintainers.antono ];
  };
}
