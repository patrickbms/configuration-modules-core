declaration template metaconfig/nginx/schema;

include 'pan/types';

@{
    Data types for an nginx server, with proxy and SSL support
}

type cipherstring = string with match(SELF, "^(TLSv1|TLSv1.1|TLSv1.2)$")
    || error("Use a modern cipher suite, for Pete's sake!");

type basic_ssl = {
    "options" ? string[]
    "requiressl" ? boolean
    "verify_client" ? string with match(SELF, "^(require|none|optional|optional_no_ca)$")
    "require" ? string
};

@{
    SSL nginx configuration
}
type httpd_ssl = {
    include basic_ssl
    "active" : boolean = true
    "ciphersuite" : cipherstring[] = list("TLSv1")
    "protocol" : cipherstring[] = list("TLSv1")
    "certificate" : string
    "key" : string
    @{ca sets ssl_client_certificate which specifies a file with trusted
    CA certificates in the PEM format used to verify client certificates and OCSP
    responses if ssl_stapling is enabled}
    "ca" ? string
    "certificate_chain_file" ? string
    "revocation_file" ? string
};

@{ Basic nginx declarations. So far we only need to declare how many
    processes and how many connections per process.
}
type nginx_global = {
    "worker_processes" : long = 4
    "worker_connections" : long = 1024
};

@{
    Description of a proxy_cache_path line
}
type nginx_cache_path = {
    "path" : string
    "levels" : long(1..2)[] = list(1, 2)
    # Sizes in MBs to keep things readable
    "keys_zone" : long{}
    "max_size" ? long
    # In minutes
    "inactive" ? long = 60
};

type nginx_cache_valid_period = {
    "codes" : long[]
    # In minutes
    "period" : long
};

@{
    Configuration entries related to a caching proxy
}
type nginx_proxy_cache = {
    "valid" ? nginx_cache_valid_period[]
    "redirect" ? type_absoluteURI[2]
    "cache" : string
};

@{ Configuration entries for a proxy, that should lie in a "location"
    section.
}
type nginx_proxy_location = {
    "set_header" ? string{}
    "redirect" ? string
    "next_upstream" ? string
    "cache" ? nginx_proxy_cache
    "pass" : type_absoluteURI
    @{Sets the HTTP protocol version for proxying. By default,
    version 1.0 is used. Version 1.1 is recommended for use with
    keepalive connections and NTLM authentication}
    "http_version" ? string with match(SELF, '^1\.[01]$')
    @{Defines a timeout for reading a response from the proxied server.
    The timeout is set only between two successive read operations,
    not for the transmission of the whole response. If the proxied
    server does not transmit anything within this time,
    the connection is closed}
    "read_timeout" ? long(0..)
};


@{nginx return diretcive}
# url: cannot use type_hostURI, should allow eg $host as host
type nginx_return = {
    "code" ? long(0..)
    "url" ? string with match(SELF, '^\w+://')
    "text" ? string
};


@{
    Structure of a location entry
}
type nginx_location = {
    "root" ? string
    "name" : string
    "operator" ? string with match(SELF, "^(=|^~|~*)$")
    "proxy" ? nginx_proxy_location
    "return" ? nginx_return
};

@{
    Description of an nginx error_page line
}
type nginx_error_page = {
    "error_codes" : long[]
    "file" : string
};

@{nginx addr: either a hostport or a port (as string)}
# ugly port range check before is_hostport (not a test function)
# cannot use is_port, as it is also not a test function
type nginx_addr = string with {
    if (match(SELF, '^\d+$')) {
        (to_long(SELF) > 0) && (to_long(SELF) < 64 * 1024);
    } else {
        is_hostport(SELF);
    };
};

type nginx_listen = {
    "addr" ? nginx_addr
    "default" : boolean = false
    "ssl" : boolean = false
};


@{nginx_server_name: either a valid hostname or _ (an invalid domain name which never intersect with any real name)}
# == test before is_hostname  (is_hostname is not a test function, it can throw errors)
type nginx_server_name = string with {SELF == '_' || is_hostname(SELF)};

@{
    An nginx server entry.
}
type nginx_server = {
    "includes" ? string[]
    "listen" : nginx_listen
    "name" : nginx_server_name[]
    "location" ? nginx_location[]
    "error_page" : nginx_error_page[] = list()
    "ssl" ? httpd_ssl
    "return" ? nginx_return
} with {
    exists(SELF['location']) || exists(SELF['return']);
};

@{ An upstream declaration for reverse proxies
}
type nginx_upstream = {
    "host" : type_hostport[]
    "ip_hash" : boolean = false
};

@{ Configuration of an HTTP instance. Some basic things will not
    change and are hardcoded in the TT template, anyways.
}
type nginx_http = {
    "includes" : string[]
    "default_type" : string = "application/octet-stream"
    "gzip" : boolean = true
    "proxy_cache_path" ? nginx_cache_path[]
    "server" : nginx_server[]
    "keepalive_timeout" : long = 65
    "upstream" ? nginx_upstream{}
};

type type_nginx = {
    "global" : nginx_global
    "http" : nginx_http[]
};
