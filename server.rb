require "sinatra"
require "net/http"
require "uri"
require "json"
require "yaml"

config = {
  freshdesk_key: ENV['FRESHDESK_API_KEY'],
  freshdesk_domain: ENV['FRESHDESK_DOMAIN'],
  freshdesk_custom_field: ENV['FRESHDESK_CUSTOM_FIELD']
}

if File.exists?(path = File.join(File.dirname(__FILE__), 'config.yml')) then
  config.merge!(YAML.load(File.read(path)) || {})
end

Config = config


def send_api_request(action, params = nil, data = nil, put = false)
  key = Config[:freshdesk_key]
  domain = Config[:freshdesk_domain]

  params ||= {}
  params["format"] = "json"

  query_parts = []
  params.each_pair {|k,v| query_parts << "#{k.to_s}=#{v.to_s}"}
  query_string = query_parts.join("&")

  uri = URI.parse("https://#{domain}.freshdesk.com/helpdesk/#{action}?#{query_string}")

  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true

  if data then
    request = put ? Net::HTTP::Put.new(uri.request_uri) : Net::HTTP::Post.new(uri.request_uri)
    request.body = data
  else
    request = Net::HTTP::Get.new(uri.request_uri)
  end

  request.basic_auth(key, "X")
  request["Content-Type"] = "application/json"

  response = http.request(request)

  unless response.code.to_s == "200" then
    throw "Response code wasn't 200! #{response.code} #{uri.to_s} \n#{response.body}"
  end

  JSON.parse response.body
end

def with_freshdesk_tickets
  return unless block_given?

  page = 1
  done = false

  while !done do
    tickets = send_api_request("tickets/filter/all_tickets", :page => page)
    done = true and next if tickets.count.zero?

    tickets.each {|tik| yield tik}
    page = page.next
  end
end

def field_for_repo(repo)
  return unless Config["repositories"]

  Config["repositories"][repo["full_name"]] || Config["repositories"][repo["name"]]
end

def with_tickets_for_issue(number, repo)
  return unless block_given?

  custom_field_name = field_for_repo(repo) || Config[:freshdesk_custom_field]

  with_freshdesk_tickets do |ticket|
    if ticket["custom_field"][custom_field_name].to_s == number.to_s then
      yield ticket
    end
  end
end

def handle_labeled(number, repo, label)
  return unless label =~ /^fixed/i

  with_tickets_for_issue(number, repo) do |ticket|
    send_api_request("tickets/#{ticket['display_id']}/conversations/note", nil, JSON.generate({
      :helpdesk_note => {
        :body => "Github issue #{repo["full_name"]}##{number} has been marked as #{label}.",
        :private => false
      }
    }))

  end
end

def handle_closed(number, repo)
  with_tickets_for_issue(number, repo) do |ticket|
    send_api_request("tickets/#{ticket['display_id']}", nil, JSON.generate({
      :helpdesk_ticket => {
        :status => 4
      }
    }), true)

  end
end

post '/endpoint' do
  body = request.env["rack.input"].read
  event = JSON.parse(body)

  case event["action"]
  when "labeled"
    handle_labeled(event["issue"]["number"], event["repository"], event["label"]["name"])
  when "closed"
    handle_closed(event["issue"]["number"], event["repository"])
  end

  "OK"
end