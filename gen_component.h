#include <signal.h>
#include <string>
#include <iostream>
#include <judo.hpp>
#include <bedrock.hpp>
using namespace bedrock;
#include <jax.hpp>
using namespace jax;
using namespace std;

namespace gencomp
{

typedef jax::RouterConnection<jax::Packet, jax::Packet> MyRouterConnection;


class Controller :
    public jax::Component,
    public MyRouterConnection::EventListener
{
public:
	Controller();
	~Controller();
	
    void init(judo::Element* e);

    std::string getNextID();

    void deliver(jax::Packet* p)
    {
         _router->deliver(p);
    }

    void disconnect();

    const std::string component_id()
        { return _component_id; }

    void setPerlFunc(const std::string& perl_func, const std::string& init_pfunc, const std::string& stop_pfunc, void* my_self);

    // Utility API
   ThreadPool* getThreadPool()
    	{ return _tpool; }
    net::SocketWatcher* getSocketWatcher()
        { return _watcher; }


    protected:
    void onRouterConnected();
    void onRouterDisconnected();
    void onRouterError();
    void onRouterPacket(jax::Packet* p);
    void establishRouterConnection(int retrycount);


private:
    ThreadPool* _tpool;
    unsigned int        _tkey;
    net::SocketWatcher* _watcher;
    Timer               _timer;

    std::string _jabberd_ip;
    unsigned int _jabberd_port;
    std::string _component_id;
    std::string _component_secret;
    unsigned int     _pending_counter;

    MyRouterConnection* _router;

    std::string _perl_func;
    std::string _init_pfunc;
    std::string _stop_pfunc;
    void* _my_self;


};

}
