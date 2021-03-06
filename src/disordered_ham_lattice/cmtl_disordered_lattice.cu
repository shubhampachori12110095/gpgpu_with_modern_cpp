// Software License for MTL
// 
// Copyright (c) 2007 The Trustees of Indiana University. 
//               2008 Dresden University of Technology and the Trustees of Indiana University. 
// All rights reserved.
// Authors: Peter Gottschling and Andrew Lumsdaine
// 
// This file is part of the Matrix Template Library
// 
// See also license.mtl.txt in the distribution.

// nvcc can't handle C++11 -> use good ole rand()

#include <iostream>
#include <cstdlib>
#include <string>
#include <cmath>
#include <utility>
#include <boost/numeric/mtl/mtl.hpp>
#include <boost/numeric/mtl/matrix/ell_matrix.hpp>

#include <boost/numeric/mtl/interface/odeint.hpp>

#include <boost/numeric/odeint.hpp>
#include <boost/numeric/odeint/algebra/vector_space_algebra.hpp>

#include <boost/timer.hpp>


namespace odeint = boost::numeric::odeint;

struct index_modulus 
{
    int N;

    index_modulus(int n) : N(n) {}

    inline int operator()(int idx) const {
	if( idx <  0 ) return idx + N;
	if( idx >= N ) return idx - N;
	return idx;
    }
};

template <typename value_type, typename Matrix>
struct disordered_lattice
{
    typedef mtl::dense_vector<value_type>         state_type;

    // v is kept outside the functor to avoid copy constructor calls
    disordered_lattice(value_type beta, const Matrix& A) 
      : beta(beta), A(A) { }

    void operator()(const state_type& q, state_type& dp) 
    {
	// compute product explicitly since implicit calculation causes expensive cudaMalloc/-Free (yet)
	dp = A * q;
	dp -= beta * q * q * q;
    }

  private:
    const value_type   beta;
    const Matrix&      A;
};




int main(int argc, char* argv[])
{
    using namespace mtl;
    mtl::vampir_trace<9999>                            tracer;

    typedef double                                     value_type;
    typedef unsigned                                   size_type;
    typedef matrix::parameters<row_major, mtl::index::c_index, non_fixed::dimensions, false, size_type> para;
    // typedef mtl::compressed2D<value_type, para>              matrix_type;
    typedef mtl::matrix::ell_matrix<value_type, para>              matrix_type;
    typedef typename disordered_lattice<value_type, matrix_type>::state_type  state_type;

    size_type n1 = argc > 1 ? atoi(argv[1]) : 512 /* 64 */, n2= n1, n= n1 * n2;
    const value_type K = 0.1, beta = 0.01, dt= 0.01, t_max= 100.0;

    std::vector<value_type> disorder( n );
    std::generate( disorder.begin(), disorder.end(), drand48 );

    index_modulus index(n);
    matrix_type A(n, n);
    {
	mtl::matrix::inserter<matrix_type> ins(A);
	for( int i=0 ; i < n1 ; ++i ) 
	    for( int j=0 ; j < n2 ; ++j ) {
		int idx = i * n2 + j; 
		ins[idx][idx] << -disorder[idx] - 4.0 * K;
		ins[idx][index(idx + 1)] << K;
		ins[idx][index(idx - 1)] << K;
		ins[idx][index(idx + n2)] << K;
		ins[idx][index(idx - n2)] << K;
	    }
    }

    std::pair<state_type, state_type> X= std::make_pair(state_type(n, 0.0), state_type(n, 0.0));
    X.first[ n1/2 * n2 + n2/2 ]= 1.0;

    odeint::symplectic_rkn_sb3a_mclachlan<
        state_type, state_type, value_type, state_type, state_type, value_type,
        odeint::vector_space_algebra , odeint::default_operations
        > stepper;

    disordered_lattice<value_type, matrix_type> sys( beta, A);
    boost::timer timer;
    odeint::integrate_const(stepper, boost::ref(sys), X, value_type(0.0), t_max, dt);
    cudaThreadSynchronize();
    std::cout << "Integration took " << timer.elapsed() << " s\n";

    std::cout << X.first[0] << " " << X.second[0] << std::endl;
    return 0;
}

