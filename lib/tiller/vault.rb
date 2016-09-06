require 'vault'
require 'pp'
require 'tiller/defaults'
require 'tiller/util'

VAULT_TOKEN_FILE = "#{Dir.home}/.vault-token"

module Tiller::VaultCommon
  def setup
    # Set our defaults if not specified
    @vault_config = Tiller::Vault::Defaults

    raise 'No Vault configuration block' unless Tiller::config.has_key?('vault')
    @vault_config.deep_merge!(Tiller::config['vault'])

    # Sanity checks
    ['url'].each {|c| raise "Missing Vault configuration #{c}" unless @vault_config.has_key?(c)}
    raise "Missing Vault token" if !(File.exists? VAULT_TOKEN_FILE || @vault_config['token'])

    Vault.configure do |config|
        # The address of the Vault server
        config.address = @vault_config['url']

        # The token to authenticate to Vault
        config.token = @vault_config['token'] || File.read(VAULT_TOKEN_FILE)

        config.ssl_verify = @vault_config['ssl_verify']
        config.ssl_pem_file = @vault_config['ssl_pem_file'] if @vault_config.has_key?(:ssl_pem_file)

        config.timeout = @vault_config['timeout']
    end

    # Check if Vault is unsealed, perform a safe check with retries on failure
    Vault.with_retries(Vault::HTTPConnectionError, Vault::HTTPError) do |attempt, e|
        Tiller::log.debug("#{self} : Connecting to Vault at #{@vault_config['url']}")
        raise "Vault at url: #{uri} is sealed" if Vault.sys.seal_status.sealed?
        Tiller::log.warn("#{self} : Received exception #{e} from Vault") if e
    end

  end

  # Interpolate configuration placeholders with values
  def interpolate(path, template_name = nil)
    path.gsub!('%e', Tiller::config[:environment])
    path.gsub!('%t', template_name) if template_name
    path
  end

end
