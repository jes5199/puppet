require 'puppet/node'
class Puppet::Node::Dashboard < Puppet::Indirector::Code
  def find(request)

    # These settings are only used when connecting to dashboard over https (SSL)
    #CERT_PATH = "/etc/puppet/ssl/certs/puppet.pem"
    #PKEY_PATH = "/etc/puppet/ssl/private_keys/puppet.pem"
    #CA_PATH   = "/etc/puppet/ssl/certs/ca.pem"

    uri = URI.parse("#{Puppet[:dashboard_url]}/nodes/#{request.key}")
    require 'net/https' if uri.scheme == 'https'

    http = Net::HTTP.new(uri.host, uri.port)
    if uri.scheme == 'https'
      cert = File.read(CERT_PATH)
      pkey = File.read(PKEY_PATH)
      http.use_ssl = true
      http.cert = OpenSSL::X509::Certificate.new(cert)
      http.key = OpenSSL::PKey::RSA.new(pkey)
      http.ca_file = CA_PATH
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    end
    result = http.start { http.request_get(uri.path, 'Accept' => 'text/yaml') }

    case result
    when Net::HTTPSuccess; puts result.body; exit 0
    else; STDERR.puts "Error: #{result.code} #{result.message.strip}\n#{result.body}"; exit 1
    end
  end
end
