#include <string>
#include <iostream>

#include <jax.h>

using namespace jax;

typedef jax::RouterConnection<Packet, Packet> MyRouterConnection;


class GenComponentController :
    public MyRouterConnection::EventListener
{
public:
    GenComponentController::GenComponentController(const std::string& serviceid, 
				   const std::string& password, 
				   const std::string& hostname, 
				   unsigned int port, bool outgoing_dir,
				   const std::string& perl_func,
				   void* my_self);

    // Router event callbacks
    void onRouterConnected();
    void onRouterDisconnected();
    void onRouterError();
    void onRouterPacket(jax::Packet* pkt);

private:
    std::string _id;
    std::string _password;
    std::string _hostname;
    unsigned int _port;
    bedrock::ThreadPool _tpool;
    bedrock::net::SocketWatcher _watcher;
    MyRouterConnection _router;
    std::string _perl_func;
    void* _my_self;
};
