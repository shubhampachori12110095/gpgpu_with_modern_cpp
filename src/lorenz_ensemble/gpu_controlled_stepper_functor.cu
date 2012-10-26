#include <iostream>
#include <vector>

#define DECORATE_CALLS
#include <boost/numeric/odeint.hpp>
#include <thrust/device_vector.h>
#include <thrust/for_each.h>
#include <thrust/iterator/zip_iterator.h>

namespace odeint = boost::numeric::odeint;



//---------------------------------------------------------------------------
template <typename T>
struct point3d {
    T x;
    T y;
    T z;
};

template <typename T>
__host__ __device__ point3d<T> operator+(point3d<T> a, point3d<T> b) {
    point3d<T> c = {a.x + b.x, a.y + b.y, a.z + b.z};
    return c;
}

template <typename T>
__host__ __device__ point3d<T> operator-(point3d<T> a, point3d<T> b) {
    point3d<T> c = {a.x - b.x, a.y - b.y, a.z - b.z};
    return c;
}

template <typename T>
__host__ __device__ point3d<T> operator*(T a, point3d<T> b) {
    point3d<T> c = {a * b.x, a * b.y, a * b.z};
    return c;
}

namespace boost { namespace numeric { namespace odeint { 
template<typename T>
struct is_resizeable< point3d<T> > : boost::false_type { };
} } } 

namespace boost { namespace numeric { namespace odeint { 
template<typename T>
struct vector_space_reduce< point3d< T > >
{
  template< class Op >
  __host__ __device__ T operator()( const point3d<T> &x , Op op , T init ) const
  {
      init = op( init , x.x );
      init = op( init , x.y );
      init = op( init , x.z );
      return init;
  }
};
} } } 
//---------------------------------------------------------------------------



typedef double value_type;
typedef point3d<value_type> state_type;

const value_type sigma = 10.0;
const value_type b = 8.0 / 3.0;
const value_type t_max = 100.0;

struct lorenz_system {
    value_type R;
    
    lorenz_system(value_type r = 0) : R(r) {}

    __host__ __device__ void operator()(const state_type &s, state_type &dsdt, value_type t) {
	dsdt.x = sigma * (s.y - s.x);
	dsdt.y = R * s.x - s.y - s.x * s.z;
	dsdt.z = s.x * s.y - b * s.z;
    }
};

struct stepper_functor
{

    odeint::controlled_runge_kutta<
        odeint::runge_kutta_cash_karp54_classic<
	    state_type, value_type, state_type, value_type,
	    odeint::vector_space_algebra, odeint::default_operations,
	    odeint::never_resizer
	    > > stepper;

    value_type t , dt;

    stepper_functor( void ) : t( 0.0 ) , dt( 0.01 ) { }

    template <class T>
    __host__ __device__ void operator()(T s)
    {
        using namespace odeint;

        state_type    &state = thrust::get<0>(s);
        lorenz_system &sys   = thrust::get<1>(s);

        const size_t max_attempts = 1000;

        size_t count = 0;
        while( t < t_max )
        {
            if( t_max < ( t + dt ) )
            {
                dt = t_max - t;
            }

            size_t trials = 0;
            controlled_step_result res = success;
            do
            {
                res = stepper.try_step( sys , state , t , dt );
                ++trials;
            }
            while( ( res == fail ) && ( trials < max_attempts ) );
            if( trials == max_attempts ) break;
            ++count;
        }
    }
};

//---------------------------------------------------------------------------
std::ostream& operator<<(std::ostream &os, state_type s) {
    return os << "[" << s.x << " " << s.y << " " << s.z << "]";
}

//---------------------------------------------------------------------------
int main(int argc, char *argv[])
{
    size_t n = argc > 1 ? atoi(argv[1]) : 1024;

    std::vector<lorenz_system> ensemble_host(n);
    value_type Rmin = 0.1 , Rmax = 50.0 , dR = ( Rmax - Rmin ) / value_type( n - 1 );
    for( size_t i=0 ; i<n ; ++i )
	ensemble_host[i] = lorenz_system(Rmin + dR * value_type( i ));

    thrust::device_vector<lorenz_system> ensemble = ensemble_host;

    state_type seed = {10, 10, 10};
    thrust::device_vector<state_type> x(n);
    thrust::fill(x.begin(), x.end(), seed);

    stepper_functor step;
    thrust::for_each(
        thrust::make_zip_iterator(
            thrust::make_tuple(x.begin(), ensemble.begin())),
        thrust::make_zip_iterator(
            thrust::make_tuple(x.end(), ensemble.end())),
        step);

    std::cout << x[0] << std::endl;
}