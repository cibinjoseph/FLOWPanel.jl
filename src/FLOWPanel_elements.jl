#=##############################################################################
# DESCRIPTION
    Definition of panel elements

# AUTHORSHIP
  * Author    : Eduardo J. Alvarez
  * Email     : Edo.AlvarezR@gmail.com
  * Created   : Jul 2018
  * License   : MIT License
=###############################################################################



const SMOOTH = 1e-2               # Smoothing radius of source panel # NOTE: This is way too large
# const SMOOTH = 1e-8
const SMOOTH2 = 1e-14             # Cutoff length for vortex ring
const SMOOTH3 = SMOOTH2           # Smoothing radius for semi-infinite vortex
const SMOOTH5 = 1e-6              # Smoothing radius for vortex ring
  # SMOOTH3 = 1e-16
const SMOOTH4 = 1e-5              # Smoothing radius for doublet panel


################################################################################
# SOURCE ELEMENTS
################################################################################



"""
Returns the velocity induced by a panel of vertices `nodes` and constant
strength source `strength` on the targets `targets`. It adds the velocity at the
i-th target to out[i].

Implementation of equations in Katz and Plotkin Sec. 10.4.1.
"""
function U_constant_source(nodes::Array{Arr1,1}, strength::Number,
                              targets::Arr2, out::Arr3; dot_with=nothing
                          ) where{T1, Arr1<:AbstractArray{T1},
                                  T2, Arr2<:AbstractArray{T2,2},
                                  T3, Arr3<:AbstractArray{T3}}

    nt = size(targets, 2)                   # Number of targets
    no = dot_with!=nothing ? length(out) : size(out, 2) # Number of outputs
    nn = length(nodes)                      # Number of nodes

    if no!=nt
        error("Invalid `out` argument. Expected size $(nt), got $(no).")
    end

    # Tangent, oblique, and normal vectors
    t1, t2, t3 = gt._calc_t1(nodes), gt._calc_t2(nodes), gt._calc_t3(nodes)
    o1, o2, o3 = gt._calc_o1(nodes), gt._calc_o2(nodes), gt._calc_o3(nodes)
    n1, n2, n3 = gt._calc_n1(nodes), gt._calc_n2(nodes), gt._calc_n3(nodes)

    # Panel local coordinate system
    # NOTE: normal is pointing out of the body, which differs from Katz and Plotkin
    O = nodes[1]                         # Origin
    # xhat, yhat, zhat = t, o, n         # Unit vectors
    # Oaxis = hcat(xhat, yhat, zhat)'    # Transformation matrix

    # Iterates over targets
    for ti in 1:nt

        # Target position in panel coordinate system
        # X = Oaxis*(targets[:, ti]-O)
        x = t1*(targets[1,ti]-O[1]) + t2*(targets[2,ti]-O[2]) + t3*(targets[3,ti]-O[3])
        y = o1*(targets[1,ti]-O[1]) + o2*(targets[2,ti]-O[2]) + o3*(targets[3,ti]-O[3])
        z = n1*(targets[1,ti]-O[1]) + n2*(targets[2,ti]-O[2]) + n3*(targets[3,ti]-O[3])

        V1, V2, V3 = zero(T3), zero(T3), zero(T3)
        dtheta = 2*pi

        nR0 = 0

        for i in 1:nn
            pi, pj = nodes[i], nodes[i%nn + 1]

            # Converts nodes to panel coordinate system
            xi = t1*(pi[1]-O[1]) + t2*(pi[2]-O[2]) + t3*(pi[3]-O[3])
            yi = o1*(pi[1]-O[1]) + o2*(pi[2]-O[2]) + o3*(pi[3]-O[3])
            zi = n1*(pi[1]-O[1]) + n2*(pi[2]-O[2]) + n3*(pi[3]-O[3])
            xj = t1*(pj[1]-O[1]) + t2*(pj[2]-O[2]) + t3*(pj[3]-O[3])
            yj = o1*(pj[1]-O[1]) + o2*(pj[2]-O[2]) + o3*(pj[3]-O[3])
            zj = n1*(pj[1]-O[1]) + n2*(pj[2]-O[2]) + n3*(pj[3]-O[3])

            dij = sqrt((xj-xi)^2 + (yj-yi)^2 + (zj-zi)^2)
            ri = sqrt((x-xi)^2 + (y-yi)^2 + (z-zi)^2)
            rj = sqrt((x-xj)^2 + (y-yj)^2 + (z-zj)^2)

            Qij = log( (ri+rj+dij)/(ri+rj-dij + SMOOTH) )

            Sij = (yj-yi)/dij
            Cij = (xj-xi)/dij

            siji = (xi-x)*Cij + (yi-y)*Sij
            sijj = (xj-x)*Cij + (yj-y)*Sij
            Rij = (x-xi)*Sij - (y-yi)*Cij

            Jij = atan( Rij*abs(z)*( ri*sijj - rj*siji ) , ri*rj*Rij^2 + z^2*sijj*siji )

            V1 -= Sij*Qij
            V2 += Cij*Qij
            V3 -= Jij

            dtheta *= Rij>=0
            nR0 += Rij==0
        end

        V3 += dtheta
        V3 *= sign(z)        # Isn't this sign already accounted for in atan2?
        V3 *= !(nR0>1)       # Singularity fix of any z position aligned with node


        # NOTE: Katz and Plotkin's potential differs from Hess and Smith's by
        #       this factor
        V1 *= 1/(4*pi)
        V2 *= 1/(4*pi)
        V3 *= 1/(4*pi)

        if dot_with!=nothing
            out[ti] += strength*(V1*t1 + V2*o1 + V3*n1)*dot_with[ti][1]
            out[ti] += strength*(V1*t2 + V2*o2 + V3*n2)*dot_with[ti][2]
            out[ti] += strength*(V1*t3 + V2*o3 + V3*n3)*dot_with[ti][3]
        else
            out[1, ti] += strength*(V1*t1 + V2*o1 + V3*n1)
            out[2, ti] += strength*(V1*t2 + V2*o2 + V3*n2)
            out[3, ti] += strength*(V1*t3 + V2*o3 + V3*n3)
        end

    end
end


"""
Returns the potential induced by a panel of vertices `nodes` and constant
strength source `strength` on the targets `targets`. It adds the potential at
the i-th target to out[i].

Implementation of equations in Katz and Plotkin Sec. 10.4.1.
"""
function phi_constant_source(nodes::Array{Arr1,1}, strength::Number,
                              targets::Arr2, out::Arr3
                            ) where{T1, Arr1<:AbstractArray{T1},
                                    T2, Arr2<:AbstractArray{T2,2},
                                    T3, Arr3<:AbstractArray{T3}}

    nt = size(targets, 2)                   # Number of targets
    no = length(out)                        # Number of outputs
    nn = length(nodes)                      # Number of nodes

    if no!=nt
        error("Invalid `out` argument. Expected size $(nt), got $(no).")
    end

    # Tangent, oblique, and normal vectors
    t1, t2, t3 = gt._calc_t1(nodes), gt._calc_t2(nodes), gt._calc_t3(nodes)
    o1, o2, o3 = gt._calc_o1(nodes), gt._calc_o2(nodes), gt._calc_o3(nodes)
    n1, n2, n3 = gt._calc_n1(nodes), gt._calc_n2(nodes), gt._calc_n3(nodes)

    # Panel local coordinate system
    # NOTE: normal is pointing out of the body, which differs from Katz and Plotkin
    O = nodes[1]                         # Origin
    # xhat, yhat, zhat = t, o, n         # Unit vectors
    # Oaxis = hcat(xhat, yhat, zhat)'    # Transformation matrix

    # Converts nodes to panel coordinate system
    # Pnodes = [Oaxis*(node-O) for node in nodes]

    # Iterates over targets
    for ti in nt

        phi = 0

        # Target position in panel coordinate system
        # X = Oaxis*(targets[:, ti]-O)
        x = t1*(targets[1,ti]-O[1]) + t2*(targets[2,ti]-O[2]) + t3*(targets[3,ti]-O[3])
        y = o1*(targets[1,ti]-O[1]) + o2*(targets[2,ti]-O[2]) + o3*(targets[3,ti]-O[3])
        z = n1*(targets[1,ti]-O[1]) + n2*(targets[2,ti]-O[2]) + n3*(targets[3,ti]-O[3])


        for i in 1:nn
            pi, pj = nodes[i], nodes[i%nn + 1]

            # Converts nodes to panel coordinate system
            xi = t1*(pi[1]-O[1]) + t2*(pi[2]-O[2]) + t3*(pi[3]-O[3])
            yi = o1*(pi[1]-O[1]) + o2*(pi[2]-O[2]) + o3*(pi[3]-O[3])
            zi = n1*(pi[1]-O[1]) + n2*(pi[2]-O[2]) + n3*(pi[3]-O[3])
            xj = t1*(pj[1]-O[1]) + t2*(pj[2]-O[2]) + t3*(pj[3]-O[3])
            yj = o1*(pj[1]-O[1]) + o2*(pj[2]-O[2]) + o3*(pj[3]-O[3])
            zj = n1*(pj[1]-O[1]) + n2*(pj[2]-O[2]) + n3*(pj[3]-O[3])

            dij = sqrt((xj-xi)^2 + (yj-yi)^2 + (zj-zi)^2)
            mij = (yj - yi)/(xj - xi)
            ri = sqrt((x-xi)^2 + (y-yi)^2 + (z-zi)^2)
            rj = sqrt((x-xj)^2 + (y-yj)^2 + (z-zj)^2)
            ei = (x - xi)^2 + (z-zi)^2
            ej = (x - xj)^2 + (z-zj)^2
            hi = (x - xi)*(y - yi)
            hj = (x - xj)*(y - yj)

            Pij = (x - xi)*(yj - yi) - (y - yi)*(xj - xi)
            Qij = log( (ri+rj+dij)/(ri+rj-dij + SMOOTH) )
            Rij = atan(mij*ei-hi, z*ri) - atan(mij*ej-hj, z*rj)

            phi += Pij/dij * Qij - abs(z)*Rij
        end

        phi *= strength

        # NOTE: Katz and Plotkin's potential differs from Hess and Smith's by
        #       this factor
        phi *= -1/(4*pi)

        out[ti] += phi
    end
end


################################################################################
# DOUBLET ELEMENTS
################################################################################

"""
Returns the velocity induced by a panel of vertices `nodes` and constant
strength doublet `strength` on the targets `targets`. It adds the velocity at
the i-th target to out[i].
"""
U_constant_doublet(args...; optargs...) = U_vortexring(args...; optargs...)

"""
Returns the potential induced by a panel of vertices `nodes` and constant
strength doublet `strength` on the targets `targets`. It adds the potential at
the i-th target to out[i].

Implementation of equations in Katz and Plotkin Sec. 10.4.2.
"""
function phi_constant_doublet(nodes::Array{Arr1,1}, strength::Number,
                              targets::Arr2, out::Arr3
                             ) where{T1, Arr1<:AbstractArray{T1},
                                     T2, Arr2<:AbstractArray{T2,2},
                                     T3, Arr3<:AbstractArray{T3}}

    nt = size(targets, 2)                   # Number of targets
    no = length(out)                        # Number of outputs
    nn = length(nodes)                      # Number of nodes

    if no!=nt
        error("Invalid `out` argument. Expected size $(nt), got $(no).")
    end

    # Tangent, oblique, and normal vectors
    t1, t2, t3 = gt._calc_t1(nodes), gt._calc_t2(nodes), gt._calc_t3(nodes)
    o1, o2, o3 = gt._calc_o1(nodes), gt._calc_o2(nodes), gt._calc_o3(nodes)
    n1, n2, n3 = gt._calc_n1(nodes), gt._calc_n2(nodes), gt._calc_n3(nodes)

    # Panel local coordinate system
    # NOTE: normal is pointing out of the body, which differs from Katz and Plotkin
    O = nodes[1]                         # Origin
    # xhat, yhat, zhat = t, o, n         # Unit vectors
    # Oaxis = hcat(xhat, yhat, zhat)'    # Transformation matrix

    # Converts nodes to panel coordinate system
    # Pnodes = [Oaxis*(node-O) for node in nodes]

    # Iterates over targets
    for ti in nt

        phi = 0

        # Target position in panel coordinate system
        # X = Oaxis*(targets[:, ti]-O)
        x = t1*(targets[1,ti]-O[1]) + t2*(targets[2,ti]-O[2]) + t3*(targets[3,ti]-O[3])
        y = o1*(targets[1,ti]-O[1]) + o2*(targets[2,ti]-O[2]) + o3*(targets[3,ti]-O[3])
        z = n1*(targets[1,ti]-O[1]) + n2*(targets[2,ti]-O[2]) + n3*(targets[3,ti]-O[3])


        for i in 1:nn
            pi, pj = nodes[i], nodes[i%nn + 1]

            # Converts nodes to panel coordinate system
            xi = t1*(pi[1]-O[1]) + t2*(pi[2]-O[2]) + t3*(pi[3]-O[3])
            yi = o1*(pi[1]-O[1]) + o2*(pi[2]-O[2]) + o3*(pi[3]-O[3])
            zi = n1*(pi[1]-O[1]) + n2*(pi[2]-O[2]) + n3*(pi[3]-O[3])
            xj = t1*(pj[1]-O[1]) + t2*(pj[2]-O[2]) + t3*(pj[3]-O[3])
            yj = o1*(pj[1]-O[1]) + o2*(pj[2]-O[2]) + o3*(pj[3]-O[3])
            zj = n1*(pj[1]-O[1]) + n2*(pj[2]-O[2]) + n3*(pj[3]-O[3])

            mij = (yj - yi)/(xj - xi)
            ri = sqrt((x-xi)^2 + (y-yi)^2 + (z-zi)^2)
            rj = sqrt((x-xj)^2 + (y-yj)^2 + (z-zj)^2)
            ei = (x - xi)^2 + (z-zi)^2
            ej = (x - xj)^2 + (z-zj)^2
            hi = (x - xi)*(y - yi)
            hj = (x - xj)*(y - yj)

            phi += atan(mij*ei-hi, z*ri) - atan(mij*ej-hj, z*rj)
        end

        phi *= strength/(4*pi)

        out[ti] += phi
    end
end


################################################################################
# VORTEX ELEMENTS
################################################################################
"""
Returns the velocity induced by a vortex ring panel of vertices `nodes` and
vortex strength `strength` on the targets `targets`. It adds the velocity at the
i-th target to out[i].
"""
function U_vortexring(nodes::Array{Arr1,1}, strength::Number,
                              targets::Arr2, out::Arr3; dot_with=nothing,
                              closed_ring::Bool=true,
                              cutoff=SMOOTH2, offset=SMOOTH5,
                          ) where{T1, Arr1<:AbstractArray{T1},
                                  T2, Arr2<:AbstractArray{T2,2},
                                  T3, Arr3<:AbstractArray{T3}}



    nt = size(targets, 2)                   # Number of targets
    no = dot_with!=nothing ? length(out) : size(out, 2) # Number of outputs
    nn = length(nodes)                      # Number of nodes

    if no!=nt
        error("Invalid `out` argument. Expected size $(nt), got $(no).")
    end

    # Iterates over targets
    for ti in 1:nt

        V1, V2, V3 = zero(T3), zero(T3), zero(T3)

        for i in 1:(nn - 1*!closed_ring)
            pi, pj = nodes[i], nodes[i%nn + 1]

            # ri = x - pi
            ri1 = targets[1, ti] - pi[1]
            ri2 = targets[2, ti] - pi[2]
            ri3 = targets[3, ti] - pi[3]

            # rj = x - pj
            rj1 = targets[1, ti] - pj[1]
            rj2 = targets[2, ti] - pj[2]
            rj3 = targets[3, ti] - pj[3]

            # rji = pj - pi
            rji1 = pj[1] - pi[1]
            rji2 = pj[2] - pi[2]
            rji3 = pj[3] - pi[3]

            # ri × rj
            rixrj1 = ri2*rj3 - ri3*rj2
            rixrj2 = ri3*rj1 - ri1*rj3
            rixrj3 = ri1*rj2 - ri2*rj1

            # ‖ ri × rj ‖^2
            dotrixrj = rixrj1^2 + rixrj2^2 + rixrj3^2

            # rji ⋅ (hat{ri} - hat{rj}), add core offset to avoid singularity
            normri = sqrt(ri1^2 + ri2^2 + ri3^2) + offset
            normrj = sqrt(rj1^2 + rj2^2 + rj3^2) + offset
            rjidothat = rji1*(ri1/normri - rj1/normrj) + rji2*(ri2/normri - rj2/normrj) + rji3*(ri3/normri - rj3/normrj)

            if dotrixrj > cutoff^2 # This makes the self induced velocity zero
                V1 += rixrj1/(dotrixrj + offset) * rjidothat
                V2 += rixrj2/(dotrixrj + offset) * rjidothat
                V3 += rixrj3/(dotrixrj + offset) * rjidothat
            end
        end

        # NOTE: Negative sign not needed since we defined rji = rj - ri
        if dot_with!=nothing
            out[ti] = strength/(4*pi)*(V1*dot_with[ti][1] + V2*dot_with[ti][2] + V3*dot_with[ti][3])
        else
            out[1, ti] = strength/(4*pi)*V1
            out[2, ti] = strength/(4*pi)*V2
            out[3, ti] = strength/(4*pi)*V3
        end

    end
end


"""
Returns the velocity induced by a semi-infinite vortex starting at point `p` in
the unitary direction `D` and vortex strength `strength` on the targets
`targets`. It adds the velocity at the i-th target to out[i].
"""
function Vsemiinfinitevortex(p::Array{T1,1}, D::Array{T2,1}, strength::RType,
                              targets::Array{Array{T3,1},1},
                              out;
                              dot_with::Union{Array{Array{T3,1},1}, Nothing}=nothing,
                              check::Bool=true
                              ) where{T1<:RType, T2<:RType, T3<:RType}
  # ERROR CASES
  if size(out)!=size(targets)
    error("Invalid `out` argument."*
          " Expected size $(size(targets)), got $(size(out)).")
  elseif check && abs(norm(D)-1.0)>1e-8
    error("Received non-unitary infinite direction D! (norm(D) = $(norm(D)))")
  end

  # Iterates over targets
  for ti in 1:size(targets, 1)

    p2 = p + dot(targets[ti]-p, D)*D
    h = norm(targets[ti]-p2)

    if h>SMOOTH3

      # Adds semi-infinite section
      if dot_with!=nothing
        out[ti] += dot(
                   strength / (4*pi*h) * cross(D, (targets[ti]-p2)/h ),
                                                                  dot_with[ti])
      else
        out[ti] .+= strength / (4*pi*h) * cross(D, (targets[ti]-p2)/h )
      end

      # Adds bound vortex section
      Vvortexring([p, p2], strength, targets[ti:ti], view(out, ti:ti);
                                          dot_with=dot_with!=nothing ? dot_with[ti:ti] : nothing,
                                          closed_ring=false)
    end

  end
end
