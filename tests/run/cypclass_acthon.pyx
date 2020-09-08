# mode: run
# tag: cpp, cpp11, pthread
# cython: experimental_cpp_class_def=True, language_level=2
from libcpp.deque cimport deque

ctypedef deque[ActhonMessageInterface] message_queue_t

cdef extern from "<semaphore.h>" nogil:
  ctypedef struct sem_t:
    pass
  int sem_init(sem_t *sem, int pshared, unsigned int value)
  int sem_wait(sem_t *sem)
  int sem_post(sem_t *sem)
  int sem_destroy(sem_t* sem)


cdef cypclass BasicQueue(ActhonQueueInterface) checklock:
  message_queue_t* _queue

  __init__(self):
    self._queue = new message_queue_t()

  __dealloc__(self):
    del self._queue

  bint is_empty(self) const:
    return self._queue.empty()

  void push(self, ActhonMessageInterface message):
    self._queue.push_back(message)
    if message._sync_method is not NULL:
      message._sync_method.insertActivity(message)

  bint activate(self):
    cdef bint one_message_processed
    if self._queue.empty():
      return False
    # Note here that according to Cython refcount conventions,
    # the front() method should have returned a new ref.
    # This is obviously not the case, so if we do nothing
    # we will, at the end of this function, loose a ref on the pointed object
    # (as we will decref the thing pointed by next_message).
    next_message = self._queue.front()
    self._queue.pop_front()
    one_message_processed = next_message.activate()
    if one_message_processed:
      if next_message._sync_method is not NULL:
        next_sync_method = next_message._sync_method
        with wlocked next_sync_method:
          next_sync_method.removeActivity(next_message)
    else:
      self._queue.push_back(next_message)
      # Don't forget to incref to avoid premature deallocation
    return one_message_processed

cdef cypclass NoneResult(ActhonResultInterface) checklock:
  void pushVoidStarResult(self, void* result):
    pass
  void pushIntResult(self, int result):
    pass
  void* getVoidStarResult(self) const:
    return NULL
  int getIntResult(self) const:
    return 0

cdef cypclass WaitResult(ActhonResultInterface) checklock:
  union result_t:
    int int_val
    void* ptr
  result_t result
  sem_t semaphore

  __init__(self):
    self.result.ptr = NULL
    sem_init(&self.semaphore, 0, 0)

  __dealloc__(self):
    sem_destroy(&self.semaphore)

  @staticmethod
  ActhonResultInterface construct():
    return WaitResult()

  void pushVoidStarResult(self, void* result):
    self.result.ptr = result
    sem_post(&self.semaphore)

  void pushIntResult(self, int result):
    self.result.int_val = result
    sem_post(&self.semaphore)

  result_t _getRawResult(self) const:
    # We must ensure a result exists, but we can let others access it immediately
    # The cast here is a way of const-casting (we're modifying the semaphore in a const method)
    sem_wait(<sem_t*> &self.semaphore)
    sem_post(<sem_t*> &self.semaphore)
    return self.result

  void* getVoidStarResult(self) const:
    res = self._getRawResult()
    return res.ptr

  int getIntResult(self) const:
    res = self._getRawResult()
    return res.int_val

cdef cypclass ActivityCounterSync(ActhonSyncInterface) checklock:
  int count
  ActivityCounterSync previous_sync

  __init__(self, ActivityCounterSync prev = <ActivityCounterSync> NULL):
    self.count = 0
    self.previous_sync = prev

  void insertActivity(self, ActhonMessageInterface msg):
    self.count += 1

  void removeActivity(self, ActhonMessageInterface msg):
    self.count -= 1

  bint isCompleted(self) const:
    return self.count == 0

  bint isActivable(self) const:
    cdef bint res = True
    if self.previous_sync is not NULL:
      prev_sync = self.previous_sync
      with rlocked prev_sync:
        res = prev_sync.isCompleted()
    return res

cdef cypclass A checklock activable:
    int a
    __init__(self):
        self.a = 0
        self._active_result_class = WaitResult.construct
        self._active_queue_class = BasicQueue()
    int getter(self) const:
        return self.a
    void setter(self, int a):
        self.a = a

def test_acthon_chain(n):
    """
    >>> test_acthon_chain(42)
    42
    """
    cdef ActhonResultInterface res
    cdef ActhonQueueInterface queue
    sync1 = ActivityCounterSync()
    with wlocked sync1:
        after_sync1 = ActivityCounterSync(sync1)
    obj = A()
    with wlocked obj:
        obj_actor = obj.__activate__()
        with wlocked obj_actor, wlocked sync1, wlocked after_sync1:
            # Pushing things in the queue
            obj_actor.setter(sync1, n)
            res = obj_actor.getter(after_sync1)
    # Processing the queue
    with rlocked obj:
        queue = obj._active_queue_class
    with wlocked queue:
        while not queue.is_empty():
            queue.activate()
    print <int> res
