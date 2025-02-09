# Forcing classes (areas, lines, points)

#=
Notes:
- The principle here is that the problem specification will supply the shape
 of the forcing region (area, line) and a model function to apply this forcing.
- The forcing model function should be able to make use of other system data, like physical
  parameters
=#

abstract type AbstractForcingModel end
abstract type AbstractRegionCache end

for ftype in [:Area,:Line,:Point]
    fmname = Symbol(string(ftype)*"ForcingModel")
    typename = lowercase(string(ftype))
    fmcache = string(ftype)*"RegionCache"

    eval(quote
      export $fmname

      struct $fmname{RT,KT,MDT<:Function} <: AbstractForcingModel
          shape :: RT
          kwargs :: KT
          fcn :: MDT
          $fmname(shape,fcn;kwargs...) = new{typeof(shape),typeof(kwargs),typeof(fcn)}(shape,kwargs,fcn)
      end
    end)
end

"""
      AreaForcingModel(shape::Union{Body,BodyList},model_function!)

  Bundles a `shape` (i.e., a `Body`, `BodyList`,) and a `model_function!` (a function
  that returns the strength of the forcing) for area-type forcing.
  `model_function!` must be in-place with a signature of the form

      model_function!(str,state,t,fcache,phys_params)

  where `str` is the strength to be returned, `state` the state vector,
  `t` is time, `fcache` is a corresponding `AreaRegionCache`
  and `phys_params` are user-supplied physical parameters. Any of these can
  be utilized to compute the strength.

  There are a number of keyword arguments that can be passed in:
  `ddftype =`,specifying the type of DDF; `spatialfield =` to provide
  an `AbstractSpatialField` to help in evaluating the strength.
  (The resulting field is available to `model_function!` in the `generated_field` field
    of `fcache`.)
""" AreaForcingModel(::Union{Body,BodyList},::Function)

"""
    AreaForcingModel(model_function!)

  Creates area-type forcing over the entire domain, using a `model_function!` (a function
  that returns the strength of the forcing).

  `model_function!` must be in-place with a signature of the form

      model_function!(str,state,t,fcache,phys_params)

  where `str` is the strength to be returned, `state` the state vector,
  `t` is time, `fcache` is a corresponding `AreaRegionCache`
  and `phys_params` are user-supplied physical parameters. Any of these can
  be utilized to compute the strength.

  The keyword `spatialfield =` can provide
  an `AbstractSpatialField` to help in evaluating the strength.
  (The resulting field is available to `model_function!` in the `generated_field` field
    of `fcache`.)
"""
AreaForcingModel(fcn::Function;kwargs...) = AreaForcingModel(nothing,fcn;kwargs...)

"""
      LineForcingModel(shape::Union{Body,BodyList},model_function!)

  Bundles a `shape` (i.e., a `Body`, `BodyList`,) and a `model_function!` (a function
  that returns the strength of the forcing) for line-type forcing.
  `model_function!` must be in-place with a signature of the form

      model_function!(str,state,t,fcache,phys_params)

  where `str` is the strength to be returned, `state` the state vector,
  `t` is time, `fcache` is a corresponding `LineRegionCache`
  and `phys_params` are user-supplied physical parameters. Any of these can
  be utilized to compute the strength.

  The keyword `ddftype =` can be used to specify the type of DDF.
""" LineForcingModel(::Union{Body,BodyList},::Function)

"""
      PointForcingModel(pts::VectorData,model_function!)

  Bundles point coordinates `pts` and a `model_function!` (a function
  that returns the strength of the forcing) for point-type forcing.
  `model_function!` must be in-place with a signature of the form

      model_function!(str,state,t,fcache,phys_params)

  where `str` is the strength to be returned, `state` the state vector,
  `t` is time, `fcache` is a corresponding `PointRegionCache`
  and `phys_params` are user-supplied physical parameters. Any of these can
  be utilized to compute the strength.

  The keyword `ddftype =` can be used to specify the type of DDF.
""" PointForcingModel(::VectorData,::Function)

"""
    PointForcingModel(point_function::Function,model_function!::Function)

Bundles a `point_function` (a function that returns the positions of forcing points)
and a `model_function` (a function that returns the strength of the forcing) for point-type forcing.

  `point_function` must have an out-of-place signature of the form

      point_function(state,t,fcache,phys_params)

  where `state` the state vector, `t` is time, `fcache` is a corresponding `PointRegionCache`
  and `phys_params` are user-supplied physical parameters. Any of these can
  be utilized to compute the positions. It must return either a vector for
  each coordinate or `VectorData`.

  `model_function!` must have an in-place signature of the form

      model_function!(str,state,t,fcache,phys_params)

  where `str` is the strength to be returned.
""" PointForcingModel(::Function,::Function)


#=
Region caches
=#

struct AreaRegionCache{MT,ST,SGT,CT<:BasicILMCache} <: AbstractRegionCache
    mask :: MT
    str :: ST
    generated_field :: SGT
    cache :: CT
end

struct LineRegionCache{ACT,ST,CT<:BasicILMCache} <: AbstractRegionCache
    s :: ACT
    str :: ST
    cache :: CT
end

struct PointRegionCache{ST,CT<:PointCollectionCache} <: AbstractRegionCache
    str :: ST
    cache :: CT
end

"""
    AreaRegionCache(shape::Body/BodyList,cache::BasicILMCache)

Create an area region (basically, a mask) of the shape(s) `shape`, using
the data in `cache` to provide the details of the grid and regularization.
""" AreaRegionCache(::Union{Body,BodyList},::BasicILMCache)

"""
    AreaRegionCache(cache::BasicILMCache)

Create an area region that spans the entire domain, using
the data in `cache` to provide the grid details.
""" AreaRegionCache(::BasicILMCache)


"""
    LineRegionCache(shape::Body/BodyList,cache::BasicILMCache)

Create a line region of the shape(s) `shape`, using
the data in `cache` to provide the details of the regularization.
""" LineRegionCache(::Union{Body,BodyList},::BasicILMCache)

"""
    PointRegionCache(pts::VectorData,cache::BasicILMCache[,kwargs])

Create a regularized point collection based on points `pts`, using the data
in `cache` to provide the details of the regularization. The `kwargs` can be used to override
the regularization choices, such as ddf.
""" PointRegionCache(::VectorData,::BasicILMCache)


# Some constructors of the region caches that distinguish scalar and vector data
for f in [:Scalar,:Vector]
    cname = Symbol("Surface"*string(f)*"Cache")
    pcname = Symbol(string(f)*"PointCollectionCache")
    gdtype = Symbol(string(f)*"GridData")
    @eval function AreaRegionCache(g::PhysicalGrid,shape::BodyList,data_prototype::$gdtype;spatialfield=nothing,kwargs...)
        cache = $cname(shape,g;kwargs...)
        m = mask(cache)
        str = similar_grid(cache)
        gf = _generatedfield(str,spatialfield,g)
        return AreaRegionCache{typeof(m),typeof(str),typeof(gf),typeof(cache)}(m,str,gf,cache)
    end

    @eval function AreaRegionCache(g::PhysicalGrid,data_prototype::$gdtype;spatialfield=nothing,kwargs...)
        cache = $cname(g;kwargs...)
        m = mask(cache)
        str = similar_grid(cache)
        gf = _generatedfield(str,spatialfield,g)
        return AreaRegionCache{typeof(m),typeof(str),typeof(gf),typeof(cache)}(m,str,gf,cache)
    end

    @eval function LineRegionCache(g::PhysicalGrid,shape::BodyList,data_prototype::$gdtype;kwargs...)
        cache = $cname(shape,g;kwargs...)
        pts = points(shape)
        s = arcs(shape)
        str = similar_surface(cache)
        return LineRegionCache{typeof(s),typeof(str),typeof(cache)}(s,str,cache)
    end

    @eval function PointRegionCache(g::PhysicalGrid,pts::VectorData,data_prototype::$gdtype;kwargs...)
        cache = $pcname(pts,g;kwargs...)

        str = similar(cache.sdata_cache)
        return PointRegionCache{typeof(str),typeof(cache)}(str,cache)
    end

    @eval function PointRegionCache(g::PhysicalGrid,pts::Function,data_prototype::$gdtype;kwargs...)
        cache = $pcname(VectorData(0),g;kwargs...)

        str = similar(cache.sdata_cache)
        return PointRegionCache{typeof(str),typeof(cache)}(str,cache)
    end

end

for f in [:AreaRegionCache,:LineRegionCache]
    @eval $f(shape::Union{Body,BodyList},cache::BasicILMCache{N,SCA};scaling=SCA,kwargs...) where {N,SCA} = $f(cache.g,shape,similar_grid(cache);scaling=scaling,kwargs...)
    @eval $f(g::PhysicalGrid,shape::Body,a...;kwargs...) = $f(g,BodyList([shape]),a...;kwargs...)
end

AreaRegionCache(cache::AbstractBasicCache;kwargs...) =
      AreaRegionCache(cache.g,similar_grid(cache);kwargs...)

AreaRegionCache(::Any,cache::AbstractBasicCache;kwargs...) =
      AreaRegionCache(cache;kwargs...)


PointRegionCache(pts::Union{VectorData,Function},cache::AbstractBasicCache;kwargs...) =
      PointRegionCache(cache.g,pts,similar_grid(cache);kwargs...)


_generatedfield(field_prototype::GridData,s,g::PhysicalGrid) = nothing
_generatedfield(field_prototype::GridData,s::Union{T,Vector{T}},g::PhysicalGrid) where {T<:AbstractSpatialField} =
          GeneratedField(field_prototype,s,g)


"""
    mask(ar::AreaRegionCache)

Return the mask for the given area region `ar`.
"""
mask(ar::AreaRegionCache) = ar.mask

"""
    arcs(lr::LineRegionCache)

Return the vector of arc length coordinates for the given line region `lr`.
"""
arcs(lr::LineRegionCache) = lr.s

"""
    points(pr::PointRegionCache)

Return the vector of coordinates of points associated with `pr`.
"""
points(pr::PointRegionCache) = points(pr.cache)

#=
Assembly of the forcing model and forcing region
=#

"""
    ForcingModelAndRegion

A type that holds the forcing model function, region, and cache
# Constructors

`ForcingModelAndRegion(model::AbstractForcingModel,cache::BasicILMCache)`

`ForcingModelAndRegion(modellist::Vector{AbstractForcingModel},cache::BasicILMCache)`

These forms gets called generally when building the extra cache. They
also gracefully generate an empty list of models if one passes along `nothing`
in the first argument.
""" ForcingModelAndRegion(::AbstractForcingModel,::BasicILMCache)

struct ForcingModelAndRegion{RT<:AbstractRegionCache,ST,MT,KT}
    region_cache :: RT
    shape :: ST
    fcn :: MT
    kwargs :: KT
end

for f in [:Area,:Line,:Point]
  modtype = Symbol(string(f)*"ForcingModel")
  regcache = Symbol(string(f)*"RegionCache")
  @eval function ForcingModelAndRegion(model::$modtype,cache::BasicILMCache)
      region_cache = $regcache(model.shape,cache;model.kwargs...)
      ForcingModelAndRegion(region_cache,model.shape,model.fcn,model.kwargs)
  end
end

function ForcingModelAndRegion(flist::Vector{<:AbstractForcingModel},cache::BasicILMCache)
   fmlist = ForcingModelAndRegion[]
   for f in flist
     push!(fmlist,ForcingModelAndRegion(f,cache))
   end
   return fmlist
end

ForcingModelAndRegion(::Any,cache::BasicILMCache) = ForcingModelAndRegion(AbstractForcingModel[],cache)

#=
Application of forcing
=#


"""
    apply_forcing!(out,x,t,fv::Vector{ForcingModelAndRegion},phys_params)

Return the total contribution of forcing in the vector `fv` to `out`,
based on the current state `x`, time `t`, and physical parameters in `phys_params`.
Note that `out` is zeroed before the contributions are added.
"""
function apply_forcing!(out,x,t,fr::Vector{<:ForcingModelAndRegion},phys_params)
    fill!(out,0.0)
    for f in fr
        _apply_forcing!(out,x,t,f,phys_params)
    end
    return out
end

"""
    apply_forcing!(dx,x,t,f::ForcingModelAndRegion,phys_params)

Return the contribution of forcing in `f` to the right-hand side `dx`
based on the current state `x`, time `t`, and physical parameters in `phys_params`.
"""
apply_forcing!(dx,x,t,fr::ForcingModelAndRegion,phys_params) = apply_forcing!(dx,x,t,[fr],phys_params)

#=
The following define how forcing of each type get applied. Each one
calls the forcing model to determine the strength.
=#

function _apply_forcing!(dx,x,t,fcache::ForcingModelAndRegion{<:AreaRegionCache},phys_params)
    @unpack region_cache, fcn = fcache
    @unpack str = region_cache

    fill!(str,0.0)
    fcn(str,x,t,region_cache,phys_params)

    dx .+= str.*mask(region_cache)
    return dx
end

function _apply_forcing!(dx,x,t,fcache::ForcingModelAndRegion{<:LineRegionCache},phys_params)
    @unpack region_cache, fcn = fcache
    @unpack str, cache = region_cache

    fill!(str,0.0)
    fcn(str,x,t,region_cache,phys_params)

    fill!(cache.gdata_cache,0.0)
    regularize!(cache.gdata_cache,str,cache)
    dx .+= cache.gdata_cache
    return dx
end

function _apply_forcing!(dx,x,t,fcache::ForcingModelAndRegion{<:PointRegionCache,T},phys_params) where T
    @unpack region_cache, fcn = fcache
    @unpack str, cache = region_cache
    @unpack regop = cache

    fill!(str,0.0)
    fcn(str,x,t,region_cache,phys_params)

    fill!(cache.gdata_cache,0.0)
    regop(cache.gdata_cache,str)
    dx .+= cache.gdata_cache
    return dx
end

function _apply_forcing!(dx,x,t,fcache::ForcingModelAndRegion{<:PointRegionCache,<:Function},phys_params)
    @unpack region_cache, shape, fcn, kwargs = fcache
    @unpack cache = region_cache

    # `shape` is a function in this case, used to obtain the point coordinates
    # Use is to to generate an instantaneous PointRegionCache
    _pts = shape(x,t,region_cache,phys_params)
    typeof(_pts) <: Tuple ? pts = VectorData(_pts...) : pts = _pts
    new_region_cache = PointRegionCache(pts,cache;kwargs...)
    @unpack str, cache = new_region_cache
    @unpack regop = cache

    fill!(str,0.0)
    fcn(str,x,t,region_cache,phys_params)

    fill!(cache.gdata_cache,0.0)
    regop(cache.gdata_cache,str)
    dx .+= cache.gdata_cache
    return dx
end
