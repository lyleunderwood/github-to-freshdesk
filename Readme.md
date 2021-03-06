Github to Freshdesk Integration
===
This is a really simple sinatra app which expects to be the endpoint for a
Github webhook. Basically any time that an issue is closed or labeled it'll
look for a ticket in Freshdesk with the Github issue number in a custom field
of the user's choosing. When the issue is closed it changes the ticket status,
and when the issue is label it adds a note with the label name. There's a bunch
of hardcoded behavior in here, which isn't great, but it should be pretty easy
to customize this basic workflow. It looks for a few environment variables:

- FRESHDESK_API_KEY
- FRESHDESK_DOMAIN
- FRESHDESK_CUSTOM_FIELD

Also, this dealie now supports a config file for multiple repos. The way this
works is you setup a custom field in Fresh Desk for each of your repos, named
like Repo#1 Ticket Reference and Repo#2 Ticket Reference or something. Then you
somehow get the internal IDs for those tickets (they look something like
<tt>repo_one_12345</tt>) and map them in the config file:

```yaml
---
repositories:
  lyleunderwood/github-to-freshdesk: github_to_freshdesk_ticket_12345
```

and obviously you can have multiple repos in here.