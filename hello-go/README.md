# Identity - Self Service

Self service means, that the user is able to register, login, logout and modify
its account on her own. 


It is based on [ory.sh Kratos](https://www.ory.sh/kratos/docs/).

## For websites

If you are using this identity management service for your website, you can
leverage many security featurs of the web browser, which are natively supported
by Kratos. If you need access to the JWT and want to build an app, use the
section [for Apps](#for-apps).

## For apps

Not implemented yet.

## With a proxy

## Without a proxy

Seems not to be the preferred way. Have to investigate, why. On the other hand, hydra doesn't seem to be slow and with horizontal scaling, the risk of failing in the single point of failure might be low enough.
