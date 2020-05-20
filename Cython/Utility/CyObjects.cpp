/////////////// CyObjects.proto ///////////////

#if !defined(__GNUC__)
#define GCC_VERSION (__GNUC__ * 10000 \
                     + __GNUC_MINOR__ * 100 \
                     + __GNUC_PATCHLEVEL__)
/* Test for GCC > 4.9.0 */
#if GCC_VERSION < 40900
#error atomic.h works only with GCC newer than version 4.9
#endif /* GNUC >= 4.9 */

#endif /* Has GCC */

#ifdef __cplusplus
  #if __cplusplus >= 201103L
    #include <atomic>
    using namespace std;
    #define CyObject_ATOMIC_REFCOUNT_TYPE atomic_int

    #include <pthread.h>

    #include <sys/types.h>

    #include <unistd.h>
    #include <sys/syscall.h>
    #include <vector>


    struct ThreadStorage {
        pid_t thread_id;
        unsigned int read_count;
        unsigned int write_count;
    };

    class RecursiveUpgradeableRWLock {
        pthread_rwlock_t rw_lock;
        pthread_mutex_t upgrade_lock;
        // Notes: This could be a rw_lock
        pthread_mutex_t thread_count_lock;
        std::vector<ThreadStorage> thread_count;
        protected:
            ThreadStorage& get_or_init_thread_count(pid_t thread_id);
        public:
            RecursiveUpgradeableRWLock()
            {
                pthread_rwlock_init(&this->rw_lock, NULL);
                pthread_mutex_init(&this->upgrade_lock, NULL);
                pthread_mutex_init(&this->thread_count_lock, NULL);
                // Reserve space for up to 8 threads
                this->thread_count.reserve(8);
            }
            void wlock();
            void rlock();
            void unlock();
            int tryrlock();
            int trywlock();
    };

    class CyObject : public PyObject {
        private:
          CyObject_ATOMIC_REFCOUNT_TYPE nogil_ob_refcnt;
          //pthread_rwlock_t ob_lock;
          RecursiveUpgradeableRWLock ob_lock;
        public:
          CyObject(): nogil_ob_refcnt(1) {}
          virtual ~CyObject() {}
          void CyObject_INCREF();
          int CyObject_DECREF();
          void CyObject_RLOCK();
          void CyObject_WLOCK();
          void CyObject_UNLOCK();
          int CyObject_TRYRLOCK();
          int CyObject_TRYWLOCK();
    };

    /* All this is made available by member injection inside the module scope */

    struct ActhonResultInterface : public CyObject {
      virtual void pushVoidStarResult(void* result) = 0;
      virtual void* getVoidStarResult() const = 0;
      virtual void pushIntResult(int result) = 0;
      virtual int getIntResult() const = 0;
      operator int() { return this->getIntResult(); }
      operator void*() { return this->getVoidStarResult(); }
    };

    struct ActhonMessageInterface;

    struct ActhonSyncInterface : public CyObject {
      virtual int isActivable() const = 0;
      virtual int isCompleted() const = 0;
      virtual void insertActivity(ActhonMessageInterface* msg) = 0;
      virtual void removeActivity(ActhonMessageInterface* msg) = 0;
    };

    struct ActhonMessageInterface : public CyObject {
      ActhonSyncInterface* _sync_method;
      ActhonResultInterface* _result;
      virtual int activate() = 0;
      ActhonMessageInterface(ActhonSyncInterface* sync_method,
        ActhonResultInterface* result_object);
      virtual ~ActhonMessageInterface();
    };

    struct ActhonQueueInterface : public CyObject {
      virtual void push(ActhonMessageInterface* message) = 0;
      virtual int activate() = 0;
      virtual int is_empty() const = 0;
    };

    struct ActhonActivableClass : public CyObject {
      ActhonQueueInterface *_active_queue_class = NULL;
      ActhonResultInterface *(*_active_result_class)(void);
      ActhonActivableClass(){} // Used in Activated classes inheritance chain (base Activated calls this, derived calls the 2 args version below)
      ActhonActivableClass(ActhonQueueInterface * queue_object, ActhonResultInterface *(*result_constructor)(void));
      virtual ~ActhonActivableClass();
    };

    static inline int _Cy_DECREF(CyObject *op) {
        return op->CyObject_DECREF();
    }

    static inline void _Cy_INCREF(CyObject *op) {
        op->CyObject_INCREF();
    }

    static inline void _Cy_RLOCK(CyObject *op) {
        if (op != NULL) {
            op->CyObject_RLOCK();
        }
        else {
            fprintf(stderr, "ERROR: trying to read lock NULL !\n");
        }
    }

    static inline void _Cy_WLOCK(CyObject *op) {
        if (op != NULL) {
            op->CyObject_WLOCK();
        }
        else {
            fprintf(stderr, "ERROR: trying to write lock NULL !\n");
        }
    }

    static inline void _Cy_UNLOCK(CyObject *op) {
        if (op != NULL) {
            op->CyObject_UNLOCK();
        }
        else {
            fprintf(stderr, "ERROR: trying to unlock NULL !\n");
        }
    }

    static inline int _Cy_TRYRLOCK(CyObject *op) {
        return op->CyObject_TRYRLOCK();
    }

    static inline int _Cy_TRYWLOCK(CyObject *op) {
        return op->CyObject_TRYWLOCK();
    }

    /* Cast argument to CyObject* type. */
    #define _CyObject_CAST(op) op

    #define Cy_INCREF(op) do {if (op != NULL) {_Cy_INCREF(_CyObject_CAST(op));}} while(0)
    #define Cy_DECREF(op) do {if (_Cy_DECREF(_CyObject_CAST(op))) {op = NULL;}} while(0)
    #define Cy_XDECREF(op) do {if (op != NULL) {Cy_DECREF(op);}} while(0)
    #define Cy_GOTREF(op)
    #define Cy_XGOTREF(op)
    #define Cy_GIVEREF(op)
    #define Cy_XGIVEREF(op)
    #define Cy_RLOCK(op) _Cy_RLOCK(op)
    #define Cy_WLOCK(op) _Cy_WLOCK(op)
    #define Cy_UNLOCK(op) _Cy_UNLOCK(op)
    #define Cy_TRYRLOCK(op) _Cy_TRYRLOCK(op)
    #define Cy_TRYWLOCK(op) _Cy_TRYWLOCK(op)
  #endif
#endif


/////////////// CyObjects ///////////////

#ifdef __cplusplus
  #include <cstdlib>
  #include <cstddef>
// atomic is already included in ModuleSetupCode
//  #include <atomic>
#else
  #error C++ needed for cython+ nogil classes
#endif /* __cplusplus */



ThreadStorage& RecursiveUpgradeableRWLock::get_or_init_thread_count(pid_t thread_id)
{
    int first_empty_index = -1;
    int match_index = -1;
    pthread_mutex_lock(&this->thread_count_lock);
    for (unsigned int i = 0; i < this->thread_count.size(); ++i) {
        if (this->thread_count[i].thread_id == thread_id)
            match_index = i;
        if (first_empty_index < 0 && this->thread_count[i].thread_id == 0)
            first_empty_index = i;
    }

    if (match_index < 0) {
    // We must get a new entry. The question is: do we have to reallocate space ?

        // First, create the temporary entry
        ThreadStorage tmp_thread_entry;
        tmp_thread_entry.thread_id = thread_id;
        tmp_thread_entry.read_count = 0;
        tmp_thread_entry.write_count = 0;

        if (first_empty_index < 0) {
            // We have to reallocate space
            match_index = this->thread_count.size();
            this->thread_count.push_back(tmp_thread_entry);
        } else {
            // We can reuse an existing and empty cell
            match_index = first_empty_index;
            this->thread_count[match_index] = tmp_thread_entry;
        }
    }
    pthread_mutex_unlock(&this->thread_count_lock);
    return this->thread_count[match_index];
}


void RecursiveUpgradeableRWLock::wlock() {
    pid_t my_tid = syscall(SYS_gettid);

    ThreadStorage& my_counts = this->get_or_init_thread_count(my_tid);
    bool has_read_lock = my_counts.read_count;
    bool has_write_lock = my_counts.write_count;

    int mutex_trylock_error = -1;

    if (!has_write_lock) {
        if (has_read_lock) {
            mutex_trylock_error = pthread_mutex_trylock(&this->upgrade_lock);
            // As you may have noticed, this is a trylock above, not a blocking lock.
            // This is because we could generate a deadlock:
            // Imagine 2 threads T1 and T2, both holding a read lock on the same lock.
            // Now, T1 tries to upgrade. So it holds the mutex, then unlock it's read lock,
            // then tries to take a write lock. As T2 still has a read lock, T1 blocks,
            // waiting for T2 to release it's read lock.
            // Now, imagine that, instead of releasing, T2 tries to upgrade.
            // It will first try to take the mutex. And won't succeed, as T1 holds it.

            // This annoying mutex is here to avoid snatching when upgrading.
            // Indeed, if you imagine T1 holding a read lock, T1 tries to upgrade,
            // and right after T3 tries to write-lock (from nothing).
            // As T1 is releasing then taking the write lock, T3 could take the write lock
            // before T1, which is not really what's intented for an upgradable lock.

            // The strategy here is to allow an "all is right" case by trying to lock
            // first in a non-blocking manner. If it succeeds, hurray, our lock
            // won't be snatched, we can continue by releasing the read lock.
            // If it doesn't, to avoid a potential deadlock, we first release the read lock
                        // then try to hold the mutex again. Our lock will be snatched.

            // So, in either case, we unlock the read lock here.
            pthread_rwlock_unlock(&this->rw_lock);
        }
        if (mutex_trylock_error != 0)
        // Two cases: failed upgrading, or trying to acquire a write lock without previous lock.
        // In both situations, we're trying here to acquire a write lock from nothing,
        // as we already dropped read lock in the failed upgrading case,
        // so blocking is allowed here (can't deadlock as we don't own other locks)
            pthread_mutex_lock(&this->upgrade_lock);
        pthread_rwlock_wrlock(&this->rw_lock);
        pthread_mutex_unlock(&this->upgrade_lock);
    }
    // If we already have the write lock we directly jump here
    ++my_counts.write_count;
}

void RecursiveUpgradeableRWLock::rlock() {
    pid_t my_tid = syscall(SYS_gettid);

    ThreadStorage& my_counts = this->get_or_init_thread_count(my_tid);
    bool has_read_lock = my_counts.read_count;
    bool has_write_lock = my_counts.write_count;

    if (!has_write_lock && !has_read_lock) {
        pthread_mutex_lock(&this->upgrade_lock);
        pthread_rwlock_rdlock(&this->rw_lock);
        pthread_mutex_unlock(&this->upgrade_lock);
    }
    // If we already have a lock (read or write), we directly jump here
    ++my_counts.read_count;
}

void RecursiveUpgradeableRWLock::unlock() {
    pid_t my_tid = syscall(SYS_gettid);

    ThreadStorage& my_counts = this->get_or_init_thread_count(my_tid);
    bool has_read_lock = my_counts.read_count;
    bool has_write_lock = my_counts.write_count;

    if (has_read_lock) {
      --my_counts.read_count;
    }
    else if (has_write_lock) {
      --my_counts.write_count;
    }
    if (!my_counts.write_count && !my_counts.read_count) {
        pthread_rwlock_unlock(&this->rw_lock);
        my_counts.thread_id = 0;
    }
}

int RecursiveUpgradeableRWLock::tryrlock() {
    int rw_trylock_error;
    pid_t my_tid = syscall(SYS_gettid);
    ThreadStorage& my_counts = this->get_or_init_thread_count(my_tid);
    bool has_read_lock = my_counts.read_count;
    bool has_write_lock = my_counts.write_count;
    if (!has_write_lock && !has_read_lock) {
        pthread_mutex_lock(&this->upgrade_lock);
        rw_trylock_error = pthread_rwlock_tryrdlock(&this->rw_lock);
        pthread_mutex_unlock(&this->upgrade_lock);
        if (rw_trylock_error) return rw_trylock_error;
    }
    ++my_counts.read_count;
    return 0;
}

int RecursiveUpgradeableRWLock::trywlock() {
    int rw_trylock_error;
    int mutex_trylock_error;
    pid_t my_tid = syscall(SYS_gettid);
    ThreadStorage& my_counts = this->get_or_init_thread_count(my_tid);
    bool has_read_lock = my_counts.read_count;
    bool has_write_lock = my_counts.write_count;
    if (!has_write_lock) {
        if (has_read_lock) {
            mutex_trylock_error = pthread_mutex_trylock(&this->upgrade_lock);
            if (mutex_trylock_error) {
              // In contrast to the blocking write lock,
              // if we fail here we do want to keep the read lock.
              return mutex_trylock_error;
            }
            // Here, we have the lock -> try to upgrade
            pthread_rwlock_unlock(&this->rw_lock);
            rw_trylock_error = pthread_rwlock_trywrlock(&this->rw_lock);
            if (rw_trylock_error) {
              // Get the read lock again. As we have the mutex, no one
              // is trying to upgrade nor to acquire a lock,
              // so the call here should return immediately
              pthread_rwlock_rdlock(&this->rw_lock);
              pthread_mutex_unlock(&this->upgrade_lock);
              return rw_trylock_error;
            }
            pthread_mutex_unlock(&this->upgrade_lock);
        }
        mutex_trylock_error = pthread_mutex_trylock(&this->upgrade_lock);
        if (mutex_trylock_error) {
          // Keep previous state, so we will indeed keep read-lock
          // if we had one.
          return mutex_trylock_error;
        }
        if (has_read_lock)
          pthread_rwlock_unlock(&this->rw_lock);
        rw_trylock_error = pthread_rwlock_trywrlock(&this->rw_lock);
        if (rw_trylock_error) {
          if (has_read_lock) {
            // Get the read lock again. As we have the mutex, no one
            // is trying to upgrade nor to acquire a lock,
            // so the call here should return immediately
            pthread_rwlock_rdlock(&this->rw_lock);
          }
          pthread_mutex_unlock(&this->upgrade_lock);
          return rw_trylock_error;
        }
        pthread_mutex_unlock(&this->upgrade_lock);
    }
    ++my_counts.write_count;
    return 0;
}


void CyObject::CyObject_INCREF()
{
  atomic_fetch_add(&(this->nogil_ob_refcnt), 1);
}

int CyObject::CyObject_DECREF()
{
  if (atomic_fetch_sub(&(this->nogil_ob_refcnt), 1) == 1) {
    delete this;
    return 1;
  }
  return 0;
}

void CyObject::CyObject_RLOCK()
{
  this->ob_lock.rlock();
}

void CyObject::CyObject_WLOCK()
{
  this->ob_lock.wlock();
}

void CyObject::CyObject_UNLOCK()
{
  this->ob_lock.unlock();
}

int CyObject::CyObject_TRYRLOCK()
{
  return this->ob_lock.tryrlock();
}

int CyObject::CyObject_TRYWLOCK()
{
  return this->ob_lock.trywlock();
}


ActhonMessageInterface::ActhonMessageInterface(ActhonSyncInterface* sync_method,
    ActhonResultInterface* result_object) : _sync_method(sync_method), _result(result_object)
{
    Cy_INCREF(this->_sync_method);
    Cy_INCREF(this->_result);
}

ActhonMessageInterface::~ActhonMessageInterface()
{
    Cy_XDECREF(this->_sync_method);
    Cy_XDECREF(this->_result);
}

ActhonActivableClass::ActhonActivableClass(ActhonQueueInterface * queue_object, ActhonResultInterface *(*result_constructor)(void))
    : _active_queue_class(queue_object), _active_result_class(result_constructor)
{
    Cy_INCREF(this->_active_queue_class);
}

ActhonActivableClass::~ActhonActivableClass()
{
    Cy_XDECREF(this->_active_queue_class);
}
