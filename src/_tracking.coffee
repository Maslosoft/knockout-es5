
# fix for ie
rFunctionName = /^function\s*([^\s(]+)/

# Lazily created by `getAllObservablesForObject` below. Has to be created lazily because the
# WeakMap factory isn't available until the module has finished loading (may be async).
objectToObservableMap = undefined

# Model tracking
# --------------
#
# This is the central feature of Knockout-ES5. We augment model objects by converting properties
# into ES5 getter/setter pairs that read/write an underlying Knockout observable. This means you can
# use plain JavaScript syntax to read/write the property while still getting the full benefits of
# Knockout's automatic dependency detection and notification triggering.
#
# For comparison, here's Knockout ES3-compatible syntax:
#
#     var firstNameLength = myModel.user().firstName().length; // Read
#     myModel.user().firstName('Bert'); // Write
#
# ... versus Knockout-ES5 syntax:
#
#     var firstNameLength = myModel.user.firstName.length; // Read
#     myModel.user.firstName = 'Bert'; // Write
# `ko.track(model)` converts each property on the given model object into a getter/setter pair that
# wraps a Knockout observable. Optionally specify an array of property names to wrap; otherwise we
# wrap all properties. If any of the properties are already observables, we replace them with
# ES5 getter/setter pairs that wrap your original observable instances. In the case of readonly
# ko.computed properties, we simply do not define a setter (so attempted writes will be ignored,
# which is how ES5 readonly properties normally behave).
#
# By design, this does *not* recursively walk child object properties, because making literally
# everything everywhere independently observable is usually unhelpful. When you do want to track
# child object properties independently, define your own class for those child objects and put
# a separate ko.track call into its constructor --- this gives you far more control.

###*
# @param {object} obj
# @param {object|array.<string>} propertyNamesOrSettings
# @param {boolean} propertyNamesOrSettings.deep Use deep track.
# @param {array.<string>} propertyNamesOrSettings.fields Array of property names to wrap.
# todo: @param {array.<string>} propertyNamesOrSettings.exclude Array of exclude property names to wrap.
# todo: @param {function(string, *):boolean} propertyNamesOrSettings.filter Function to filter property
#   names to wrap. A function that takes ... params
# @return {object}
###

track = (obj, propertyNamesOrSettings) ->
  if !obj or typeof obj != 'object'
    throw new Error('When calling ko.track, you must pass an object as the first parameter.')
  propertyNames = undefined
  if isPlainObject(propertyNamesOrSettings)
    # defaults
    propertyNamesOrSettings.deep = propertyNamesOrSettings.deep or false
    propertyNamesOrSettings.fields = propertyNamesOrSettings.fields or Object.getOwnPropertyNames(obj)
    propertyNamesOrSettings.lazy = propertyNamesOrSettings.lazy or false
    wrap obj, propertyNamesOrSettings.fields, propertyNamesOrSettings
  else
    propertyNames = propertyNamesOrSettings or Object.getOwnPropertyNames(obj)
    wrap obj, propertyNames, {}
  obj

getFunctionName = (ctor) ->
  if ctor.name
    return ctor.name
  (ctor.toString().trim().match(rFunctionName) or [])[1]

canTrack = (obj) ->
  obj and typeof obj == 'object' and getFunctionName(obj.constructor) == 'Object'

createPropertyDescriptor = (originalValue, prop, map) ->
  isObservable = ko.isObservable(originalValue)
  isArray = !isObservable and Array.isArray(originalValue)
  observable = if isObservable then originalValue else if isArray then ko.observableArray(originalValue) else ko.observable(originalValue)

  map[prop] = ->
    observable

  # add check in case the object is already an observable array
  if isArray or isObservable and 'push' of observable
    notifyWhenPresentOrFutureArrayValuesMutate ko, observable
  {
    configurable: true
    enumerable: true
    get: observable
    set: if ko.isWriteableObservable(observable) then observable else undefined
  }

createLazyPropertyDescriptor = (originalValue, prop, map) ->

  getOrCreateObservable = (value, writing) ->
    if observable
      return if writing then observable(value) else observable
    if Array.isArray(value)
      observable = ko.observableArray(value)
      notifyWhenPresentOrFutureArrayValuesMutate ko, observable
      return observable
    observable = ko.observable(value)

  if ko.isObservable(originalValue)
    # no need to be lazy if we already have an observable
    return createPropertyDescriptor(originalValue, prop, map)
  observable = undefined

  map[prop] = ->
    getOrCreateObservable originalValue

  {
    configurable: true
    enumerable: true
    get: ->
      getOrCreateObservable(originalValue)()
    set: (value) ->
      getOrCreateObservable value, true
      return

  }

wrap = (obj, props, options) ->
  if !props.length
    return
  allObservablesForObject = getAllObservablesForObject(obj, true)
  descriptors = {}
  props.forEach (prop) ->
    # Skip properties that are already tracked
    if prop of allObservablesForObject
      return
    # Skip properties where descriptor can't be redefined
    if Object.getOwnPropertyDescriptor(obj, prop).configurable == false
      return
    originalValue = obj[prop]
    descriptors[prop] = (if options.lazy then createLazyPropertyDescriptor else createPropertyDescriptor)(originalValue, prop, allObservablesForObject)
    if options.deep and canTrack(originalValue)
      wrap originalValue, Object.keys(originalValue), options
    return
  Object.defineProperties obj, descriptors
  return

isPlainObject = (obj) ->
  ! !obj and typeof obj == 'object' and obj.constructor == Object

# Gets or creates the hidden internal key-value collection of observables corresponding to
# properties on the model object.

getAllObservablesForObject = (obj, createIfNotDefined) ->
  if !objectToObservableMap
    objectToObservableMap = weakMapFactory()
  result = objectToObservableMap.get(obj)
  if !result and createIfNotDefined
    result = {}
    objectToObservableMap.set obj, result
  result

# Removes the internal references to observables mapped to the specified properties
# or the entire object reference if no properties are passed in. This allows the
# observables to be replaced and tracked again.

untrack = (obj, propertyNames) ->
  if !objectToObservableMap
    return
  if arguments.length == 1
    objectToObservableMap['delete'] obj
  else
    allObservablesForObject = getAllObservablesForObject(obj, false)
    if allObservablesForObject
      propertyNames.forEach (propertyName) ->
        delete allObservablesForObject[propertyName]
        return
  return

# ---
# generated by js2coffee 2.2.0