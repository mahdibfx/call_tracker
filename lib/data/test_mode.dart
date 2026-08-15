/// Test flag for the incoming-call feature — yes/no, nothing in between.
///
/// `GET /students/lookup?phone=` is the only way to put a name to a caller who
/// isn't on the roster this session has already synced, and it isn't deployed
/// yet. Until it is, an incoming call that matches nothing resolves to nobody
/// and is dropped on purpose (it's assumed to be one of the agent's private
/// calls) — which leaves no way to tell a working capture from a broken one.
///
/// With this on, a caller nothing matches becomes [IncomingCallService.mockCaller]
/// instead of being dropped, so native capture → queue → drain → summary screen
/// can be exercised end to end from any phone. It also puts the "simulate an
/// incoming call" buttons on the Dashboard's test block, which push a fake call
/// through that same path with no second phone involved.
///
/// A real roster match still wins over the mock, so calls from a student's
/// number keep showing that student's real name.
///
/// Flip to false before shipping to agents: with it on the app asks the agent
/// to log every call he receives, private ones included.
const bool kIncomingCallTestMode = true;
