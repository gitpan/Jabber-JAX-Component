#include <string>
#include <iostream>

#include <jax.hpp>
using namespace jax;

typedef jax::RouterConnection<Packet, Packet> MyClientConnection;

class ClientController :
    public MyClientConnection::EventListener
{
public:
    ClientController::ClientController(const std::string& serviceid, 
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

   // Custom callback before and after presence is sent
    void onCallBack();

private:

    std::string _id;
    std::string _password;
    std::string _hostname;
    unsigned int _port;
    bedrock::ThreadPool _tpool;
    bedrock::net::SocketWatcher _watcher;
    MyClientConnection _router;
    std::string _perl_func;
    void* _my_self;
};
