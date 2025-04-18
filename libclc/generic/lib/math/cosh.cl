//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include <clc/clc.h>
#include <clc/clcmacro.h>
#include <clc/math/math.h>
#include <clc/math/tables.h>

_CLC_OVERLOAD _CLC_DEF float cosh(float x) {

    // After dealing with special cases the computation is split into regions as follows.
    // abs(x) >= max_cosh_arg:
    // cosh(x) = sign(x)*Inf
    // abs(x) >= small_threshold:
    // cosh(x) = sign(x)*exp(abs(x))/2 computed using the
    // splitexp and scaleDouble functions as for exp_amd().
    // abs(x) < small_threshold:
    // compute p = exp(y) - 1 and then z = 0.5*(p+(p/(p+1.0)))
    // cosh(x) is then z.

    const float max_cosh_arg = 0x1.65a9fap+6f;
    const float small_threshold = 0x1.0a2b24p+3f;

    uint ux = as_uint(x);
    uint aux = ux & EXSIGNBIT_SP32;
    float y = as_float(aux);

    // Find the integer part y0 of y and the increment dy = y - y0. We then compute
    // z = sinh(y) = sinh(y0)cosh(dy) + cosh(y0)sinh(dy)
    // z = cosh(y) = cosh(y0)cosh(dy) + sinh(y0)sinh(dy)
    // where sinh(y0) and cosh(y0) are tabulated above.

    int ind = (int)y;
    ind = (uint)ind > 36U ? 0 : ind;

    float dy = y - ind;
    float dy2 = dy * dy;

    float sdy = mad(dy2,
                    mad(dy2,
                        mad(dy2,
                            mad(dy2,
                                mad(dy2,
                                    mad(dy2, 0.7746188980094184251527126e-12f, 0.160576793121939886190847e-9f),
                                    0.250521176994133472333666e-7f),
                                0.275573191913636406057211e-5f),
                            0.198412698413242405162014e-3f),
                        0.833333333333329931873097e-2f),
                    0.166666666666666667013899e0f);
    sdy = mad(sdy, dy*dy2, dy);

    float cdy = mad(dy2,
                    mad(dy2,
                        mad(dy2,
                            mad(dy2,
                                mad(dy2,
                                    mad(dy2, 0.1163921388172173692062032e-10f, 0.208744349831471353536305e-8f),
                                    0.275573350756016588011357e-6f),
                                0.248015872460622433115785e-4f),
                            0.138888888889814854814536e-2f),
                        0.416666666666660876512776e-1f),
                    0.500000000000000005911074e0f);
    cdy = mad(cdy, dy2, 1.0f);

    float2 tv = USE_TABLE(sinhcosh_tbl, ind);
    float z = mad(tv.s0, sdy, tv.s1 * cdy);

    // When exp(-x) is insignificant compared to exp(x), return exp(x)/2
    float t = exp(y - 0x1.62e500p-1f);
    float zsmall = mad(0x1.a0210ep-18f, t, t);
    z = y >= small_threshold ? zsmall : z;

    // Corner cases
    z = y >= max_cosh_arg ? as_float(PINFBITPATT_SP32) : z;
    z = aux > PINFBITPATT_SP32 ? as_float(QNANBITPATT_SP32) : z;
    z = aux < 0x38800000 ? 1.0f : z;

    return z;
}

_CLC_UNARY_VECTORIZE(_CLC_OVERLOAD _CLC_DEF, float, cosh, float);

#ifdef cl_khr_fp64
#pragma OPENCL EXTENSION cl_khr_fp64 : enable

_CLC_OVERLOAD _CLC_DEF double cosh(double x) {

    // After dealing with special cases the computation is split into
    // regions as follows:
    //
    // abs(x) >= max_cosh_arg:
    // cosh(x) = sign(x)*Inf
    //
    // abs(x) >= small_threshold:
    // cosh(x) = sign(x)*exp(abs(x))/2 computed using the
    // splitexp and scaleDouble functions as for exp_amd().
    //
    // abs(x) < small_threshold:
    // compute p = exp(y) - 1 and then z = 0.5*(p+(p/(p+1.0)))
    // cosh(x) is then sign(x)*z.

    // This is ln(2^1025)
    const double max_cosh_arg = 7.10475860073943977113e+02;      // 0x408633ce8fb9f87e

    // This is where exp(-x) is insignificant compared to exp(x) = ln(2^27)
    const double small_threshold = 0x1.2b708872320e2p+4;

    double y = fabs(x);

    // In this range we find the integer part y0 of y 
    // and the increment dy = y - y0. We then compute
    // z = cosh(y) = cosh(y0)cosh(dy) + sinh(y0)sinh(dy)
    // where sinh(y0) and cosh(y0) are tabulated above.

    int ind = min((int)y, 36);
    double dy = y - ind;
    double dy2 = dy * dy;

    double sdy = dy * dy2 *
	         fma(dy2,
		     fma(dy2,
			 fma(dy2,
			     fma(dy2,
				 fma(dy2,
				     fma(dy2, 0.7746188980094184251527126e-12, 0.160576793121939886190847e-9),
				     0.250521176994133472333666e-7),
				 0.275573191913636406057211e-5),
			     0.198412698413242405162014e-3),
			 0.833333333333329931873097e-2),
		     0.166666666666666667013899e0);

    double cdy = dy2 * fma(dy2,
	                   fma(dy2,
			       fma(dy2,
				   fma(dy2,
				       fma(dy2,
					   fma(dy2, 0.1163921388172173692062032e-10, 0.208744349831471353536305e-8),
					   0.275573350756016588011357e-6),
				       0.248015872460622433115785e-4),
				   0.138888888889814854814536e-2),
			       0.416666666666660876512776e-1),
			   0.500000000000000005911074e0);

    // At this point sinh(dy) is approximated by dy + sdy,
    // and cosh(dy) is approximated by 1 + cdy.
    double2 tv = USE_TABLE(cosh_tbl, ind);
    double cl = tv.s0;
    double ct = tv.s1;
    tv = USE_TABLE(sinh_tbl, ind);
    double sl = tv.s0;
    double st = tv.s1;

    double z = fma(sl, dy, fma(sl, sdy, fma(cl, cdy, fma(st, dy, fma(st, sdy, ct*cdy)) + ct))) + cl;

    // Other cases
    z = y < 0x1.0p-28 ? 1.0 : z;

    double t = exp(y - 0x1.62e42fefa3800p-1);
    t =  fma(t, -0x1.ef35793c76641p-45, t);
    z = y >= small_threshold ? t : z;

    z = y >= max_cosh_arg ? as_double(PINFBITPATT_DP64) : z;

    z = isinf(x) | isnan(x) ? y : z;

    return z;

}

_CLC_UNARY_VECTORIZE(_CLC_OVERLOAD _CLC_DEF, double, cosh, double)

#endif

#ifdef cl_khr_fp16

#pragma OPENCL EXTENSION cl_khr_fp16 : enable

_CLC_DEFINE_UNARY_BUILTIN_FP16(cosh)

#endif
