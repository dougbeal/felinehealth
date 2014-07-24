/**
* @OnlyCurrentDoc
 */
n = 'FelineBloodGlucoseLibraryProject';
t = this;
f = t[n];

function containerOnInstall() {
  f.onInstall(n);
}

__slice = [].slice;

function containerOnconfigSidebarShim() {
 
  var args, fnName;
  fnName = arguments[0], args = 2 <= arguments.length ? __slice.call(arguments, 1) : [];
  f.dump( fnName );
  f.dump( arguments );
  f.flushLog();
  return f[fnName].apply(f, args);
};

function noop() 
{
  f.dump('test');
  f.flushLog();
}
