#include <iostream>
#include <vector>
#include <utility>
#include <tuple>
#include <cmath>

#include <vexcl/vexcl.hpp>

#include <boost/array.hpp>
#include <boost/numeric/odeint.hpp>
#include <boost/numeric/odeint/external/vexcl/vexcl_resize.hpp>


namespace odeint = boost::numeric::odeint;

typedef double value_type;

typedef vex::vector< value_type > state_type;

struct sys_func
{

    const state_type &omega;

    sys_func( const state_type &_omega )
        : omega( _omega )
    { }

    void operator()( const state_type &x , state_type &dxdt , value_type t ) const
    {
        static VEX_STENCIL_OPERATOR(S, double, 3, 1,
                "return sin(X[1] - X[0]) + sin(X[0] - X[-1]);",
                omega.queue_list());
        dxdt = omega + S( x );
    }
};

size_t n;
const value_type dt = 0.01;
const value_type t_max = 100.0;

int main( int argc , char **argv )
{
    n = ( argc > 1 ) ? atoi(argv[1]) : 1024;
    const value_type epsilon = 6.0 / ( n * n ); // should be < 8/N^2 to see phase locking
    using namespace std;

    vex::Context ctx( vex::Filter::Exclusive( vex::Filter::Env ) );
    std::cout << ctx << std::endl;

    // initialize omega and the state of the lattice

    std::vector< value_type > omega( n );
    std::vector< value_type > x( n );
    for( size_t i=0 ; i<n ; ++i )
    {
        x[i] = 2.0 * M_PI * drand48();
        omega[i] = double( n - i ) * epsilon; // decreasing frequencies
    }

    state_type X( ctx.queue() , x );
    state_type Omega( ctx.queue() , omega );

    odeint::runge_kutta4<
	    state_type , value_type , state_type , value_type ,
	    odeint::vector_space_algebra , odeint::default_operations
	    > stepper;

    odeint::integrate_const( stepper , sys_func( Omega ) , X , value_type( 0.0 ) , t_max , dt );

    std::vector< value_type > res( n );
    vex::copy( X , res );
    cout << res[0] << endl;
//    for( size_t i=0 ; i<n ; ++i ) cout << res[i] << endl;

    return 0;
}
