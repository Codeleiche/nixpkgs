{ stdenv
, lib
, fetchzip
, python310
, rtlcss
, wkhtmltopdf
, nixosTests
}:

let
  python = python310.override {
    packageOverrides = self: super: {
      flask = super.flask.overridePythonAttrs (old: rec {
        version = "2.3.3";
        src = old.src.override {
          inherit version;
          hash = "sha256-CcNHqSqn/0qOfzIGeV8w2CZlS684uHPQdEzVccpgnvw=";
        };
      });
      werkzeug = super.werkzeug.overridePythonAttrs (old: rec {
        version = "3.0.3";#"3.0.0";#2.3.7
        src = old.src.override {
          inherit version;
          hash = "sha256-CX5b/anwq6jaa4VFFG3vSB0Gqn0yZudEjizM9n3YvRg=";#"sha256-P//03MMttS7zzJTf8wAKPChGiQ86WlGACie5CcXncPA=";# from 3.0.0 hash = "sha256-K4wORHtLnbzIXdl7butNy69si2w74L1lTiVVPgohV9g="; #from 2.3.7
        };
      });
      rjsmin = super.rjsmin.overridePythonAttrs (old: rec {
        version = "1.1.0";
        src = old.src.override {
          inherit version;
          hash = "sha256-sV3HXHH2XZSTqMf6Iz/c7II+PxuIrYSoQ//vSbM4rDI=";
        };
      });
    };
  };

  odoo_version = "17.0";
  odoo_release = "20240603";
in python.pkgs.buildPythonApplication rec {
  pname = "odoo";
  version = "${odoo_version}.${odoo_release}";

  format = "setuptools";

  # latest release is at https://github.com/odoo/docker/blob/master/17.0/Dockerfile
  src = fetchzip {
    url = "https://nightly.odoo.com/${odoo_version}/nightly/src/odoo_${version}.zip";
    name = "${pname}-${version}";
    hash = "sha256-EhPCTDQKcUePA0eCoZlvEiCt+kxE+i/xRh9fGY+pvfM=";#"sha256-jMAzIKDG6mRfdgrFa6yyq6OVj4og6O8HC5PrMfYRQbg="; # odoo
  };

  # needs some investigation
  doCheck = false;

  makeWrapperArgs = [
    "--prefix" "PATH" ":" "${lib.makeBinPath [ wkhtmltopdf rtlcss ]}"
  ];

  propagatedBuildInputs = with python.pkgs; [
    babel
    chardet
    cryptography
    decorator
    docutils
    ebaysdk
    freezegun
    gevent
    greenlet
    idna
    jinja2
    libsass
    lxml
    markupsafe
    num2words
    ofxparse
    passlib
    pillow
    polib
    psutil
    psycopg2
    pydot
    pyopenssl
    pypdf2
    pyserial
    python-dateutil
    python-ldap
    python-stdnum
    pytz
    pyusb
    qrcode
    reportlab
    requests
    urllib3
    vobject
    werkzeug
    xlrd
    xlsxwriter
    xlwt
    zeep
    rjsmin

    setuptools
    mock
  ];

  # takes 5+ minutes and there are not files to strip
  dontStrip = true;

  passthru = {
    updateScript = ./update.sh;
    tests = {
      inherit (nixosTests) odoo;
    };
  };

  meta = with lib; {
    description = "Open Source ERP and CRM";
    homepage = "https://www.odoo.com/";
    license = licenses.lgpl3Only;
    maintainers = with maintainers; [ mkg20001 ];
  };
}
