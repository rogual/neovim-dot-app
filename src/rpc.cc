#include <cassert>

#include "rpc.h"
#include "client.h"

RPC::RPC(Client &client, int id):
    client(client),
    id(id),
    resolved(false)
{
    pthread_mutex_lock(&client.mutex);
    client.rpc_map[id] = this;
    pthread_mutex_unlock(&client.mutex);
}

void RPC::then(callback_t callback)
{
    assert (!this->callback);
    this->callback = callback;
}
