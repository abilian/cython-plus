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
        #include <cstdint>
        using namespace std;
        #define CyObject_ATOMIC_REFCOUNT_TYPE atomic_int
        #define CyObject_NO_OWNER -1
        #define CyObject_MANY_OWNERS -2

        #define CyObject_CONTENDING_WRITER_FLAG (1 << 0)
        #define CyObject_CONTENDING_READER_FLAG (1 << 1)

        #define CyObject_RAISE_ON_CONTENTION 0

        #include <pthread.h>

        #include <sys/types.h>

        #include <unistd.h>
        #include <sys/syscall.h>
        #include <vector>

        #include <type_traits>


        class CyLock {
            static pthread_mutex_t log_guard;
            protected:
                pthread_mutex_t guard;
                pthread_cond_t readers_have_left;
                pthread_cond_t writer_has_left;
                atomic<pid_t> owner_id;
                atomic_int32_t readers_nb;
                uint32_t write_count;
                const char *owner_context;
            public:
                CyLock() {
                    pthread_mutex_init(&this->guard, NULL);
                    pthread_cond_init(&this->readers_have_left, NULL);
                    pthread_cond_init(&this->writer_has_left, NULL);
                    this->owner_id = CyObject_NO_OWNER;
                    this->readers_nb = 0;
                    this->write_count = 0;
                }
                void wlock(const char * context);
                void rlock(const char * context);
                void unwlock();
                void unrlock();
                int tryrlock();
                int trywlock();
        };
        #if CyObject_RAISE_ON_CONTENTION == 0
        pthread_mutex_t CyLock::log_guard = PTHREAD_MUTEX_INITIALIZER;
        #endif

        struct CyPyObject {
            PyObject_HEAD
        };

        class CyObject : public CyPyObject {
            private:
                CyObject_ATOMIC_REFCOUNT_TYPE nogil_ob_refcnt;
                CyLock ob_lock;
            public:
                CyObject(): nogil_ob_refcnt(1) {}
                virtual ~CyObject() {}
                void CyObject_INCREF();
                int CyObject_DECREF();
                int CyObject_GETREF();
                void CyObject_RLOCK(const char * context);
                void CyObject_WLOCK(const char * context);
                void CyObject_UNRLOCK();
                void CyObject_UNWLOCK();
                int CyObject_TRYRLOCK();
                int CyObject_TRYWLOCK();
        };

        class Cy_rlock_guard {
            CyObject* o;
            public:
                Cy_rlock_guard(CyObject* o, const char * context) : o(o) {
                    if (o != NULL) {
                        o->CyObject_RLOCK(context);
                    }
                    else {
                        fprintf(stderr, "ERROR: trying to rlock NULL !\n");
                    }
                }
                ~Cy_rlock_guard() {
                    if (this->o != NULL) {
                        this->o->CyObject_UNRLOCK();
                    }
                    else {
                        fprintf(stderr, "ERROR: trying to unrlock NULL !\n");
                    }
                }
        };

        class Cy_wlock_guard {
            CyObject* o;
            public:
                Cy_wlock_guard(CyObject* o, const char * context) : o(o) {
                    if (o != NULL) {
                        o->CyObject_WLOCK(context);
                    }
                    else {
                        fprintf(stderr, "ERROR: trying to wlock NULL !\n");
                    }
                }
                ~Cy_wlock_guard() {
                    if (this->o != NULL) {
                        this->o->CyObject_UNWLOCK();
                    }
                    else {
                        fprintf(stderr, "ERROR: trying to unwlock NULL !\n");
                    }
                }
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
            ActhonMessageInterface(ActhonSyncInterface* sync_method, ActhonResultInterface* result_object);
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


        /*
            * Let Cy_INCREF, Cy_DECREF and Cy_XDECREF accept any argument type
            * but only do the work when the argument is actually a CyObject
            */
        template <typename T, typename std::enable_if<!std::is_convertible<T, CyObject*>::value, int>::type = 0>
        static inline void Cy_DECREF(T) {}

        template <typename T, typename std::enable_if<!std::is_convertible<T, CyObject*>::value, int>::type = 0>
        static inline void Cy_XDECREF(T) {}

        template <typename T, typename std::enable_if<!std::is_convertible<T, CyObject*>::value, int>::type = 0>
        static inline void Cy_INCREF(T) {}

        template <typename T, typename std::enable_if<std::is_convertible<T, CyObject*>::value, int>::type = 0>
        static inline void Cy_DECREF(T &ob) {
            if(ob->CyObject_DECREF())
                ob = NULL;
        }

        template <typename T, typename std::enable_if<std::is_convertible<T, CyObject*>::value, int>::type = 0>
        static inline void Cy_XDECREF(T &ob) {
            if (ob != NULL) {
                if(ob->CyObject_DECREF())
                    ob = NULL;
            }
        }

        template <typename T, typename std::enable_if<std::is_convertible<T, CyObject*>::value, int>::type = 0>
        static inline void Cy_INCREF(T ob) {
            if (ob != NULL)
                ob->CyObject_INCREF();
        }

        static inline int _Cy_GETREF(CyObject *ob) {
            return ob->CyObject_GETREF();
        }

        static inline void _Cy_RLOCK(CyObject *ob, const char *context) {
            if (ob != NULL) {
                ob->CyObject_RLOCK(context);
            }
            else {
                fprintf(stderr, "ERROR: trying to read lock NULL !\n");
            }
        }

        static inline void _Cy_WLOCK(CyObject *ob, const char *context) {
            if (ob != NULL) {
                ob->CyObject_WLOCK(context);
            }
            else {
                fprintf(stderr, "ERROR: trying to write lock NULL !\n");
            }
        }

        static inline void _Cy_UNRLOCK(CyObject *ob) {
            if (ob != NULL) {
                ob->CyObject_UNRLOCK();
            }
            else {
                fprintf(stderr, "ERROR: trying to unrlock NULL !\n");
            }
        }

        static inline void _Cy_UNWLOCK(CyObject *ob) {
            if (ob != NULL) {
                ob->CyObject_UNWLOCK();
            }
            else {
                fprintf(stderr, "ERROR: trying to unwlock NULL !\n");
            }
        }

        static inline int _Cy_TRYRLOCK(CyObject *ob) {
            return ob->CyObject_TRYRLOCK();
        }

        static inline int _Cy_TRYWLOCK(CyObject *ob) {
            return ob->CyObject_TRYWLOCK();
        }

        /*
            * Check whether a CyObject is an instance of a given type.
            * 
            * template:
            *  - T: the type
            */
        template <typename T, typename O>
        static inline int isinstanceof(O ob) {
            static_assert(std::is_convertible<T, CyObject *>::value, "wrong type 'T' for isinstanceof[T]");
            return dynamic_cast<T>(ob) != NULL;
        }

        /*
            * Cast from CyObject to PyObject:
            *  - borrow an atomic reference
            *  - return a new Python reference
            * 
            * Note: an optimisation could be to steal a reference but only decrement
            * when Python already has a reference, because calls to this function
            * are likely (certain even?) to be followed by a Cy_DECREF; stealing the
            * reference would mean that Cy_DECREF should not be called after this.
            */
        static inline PyObject* __Pyx_PyObject_FromCyObject(CyObject * cy) {
            // convert NULL to None
            if (cy == NULL) {
                Py_INCREF(Py_None);
                return Py_None;
            }
            PyObject * ob = reinterpret_cast<PyObject *>(static_cast<CyPyObject *>(cy));
            // artificial atomic increment the first time Python gets a reference
            if (Py_REFCNT(ob) == 0)
                cy->CyObject_INCREF();
            // return a new Python reference
            Py_INCREF(ob);
            return ob;
        }

        /*
            * Cast from PyObject to CyObject:
            *  - borrow an Python reference
            *  - return a new atomic reference
            * 
            * In case of conversion failure:
            *  - raise an exception
            *  - return NULL
            * 
            * template:
            *  - U: the type of the underlying cypclass
            */
        template <typename U>
        static inline U* __Pyx_PyObject_AsCyObject(PyObject * ob, PyTypeObject * type) {
            // the PyObject is not of the expected type
            if ( !PyType_IsSubtype(Py_TYPE(ob), type) ) {
                PyErr_Format(PyExc_TypeError, "Cannot convert PyObject %s to CyObject %s", Py_TYPE(ob)->tp_name, type->tp_name);
                return NULL;
            }

            CyPyObject * wrapper = (CyPyObject *)ob;
            U * underlying = dynamic_cast<U *>(static_cast<CyObject *>(wrapper));

            // failed dynamic cast: should not happen
            if (underlying == NULL) {
                PyErr_Format(PyExc_TypeError, "Could not convert %s PyObject wrapper to its underlying CyObject", type->tp_name);
                return NULL;
            }

            // return a new atomic reference
            underlying->CyObject_INCREF();
            return underlying;
        }


        /* Cast argument to CyObject* type. */
        #define _CyObject_CAST(ob) ob

        #define Cy_GETREF(ob) (_Cy_GETREF(_CyObject_CAST(ob)))
        #define Cy_GOTREF(ob)
        #define Cy_XGOTREF(ob)
        #define Cy_GIVEREF(ob)
        #define Cy_XGIVEREF(ob)
        #define Cy_RLOCK(ob) _Cy_RLOCK(ob, NULL)
        #define Cy_WLOCK(ob) _Cy_WLOCK(ob, NULL)
        #define Cy_RLOCK_CONTEXT(ob, context) _Cy_RLOCK(ob, context)
        #define Cy_WLOCK_CONTEXT(ob, context) _Cy_WLOCK(ob, context)
        #define Cy_UNRLOCK(ob) _Cy_UNRLOCK(ob)
        #define Cy_UNWLOCK(ob) _Cy_UNWLOCK(ob)
        #define Cy_TRYRLOCK(ob) _Cy_TRYRLOCK(ob)
        #define Cy_TRYWLOCK(ob) _Cy_TRYWLOCK(ob)
    #endif
#endif


/////////////// CyObjects ///////////////

#ifdef __cplusplus
    #include <cstdlib>
    #include <cstddef>
    #include <sstream>
    #include <iostream>
    #include <stdexcept>
// atomic is already included in ModuleSetupCode
//  #include <atomic>
#else
    #error C++ needed for cython+ nogil classes
#endif /* __cplusplus */


void CyLock::rlock(const char *context) {
    pid_t caller_id = syscall(SYS_gettid);

    if (this->owner_id == caller_id) {
        ++this->readers_nb;
        return;
    }

    pthread_mutex_lock(&this->guard);

    if (this->write_count > 0) {
        #if CyObject_RAISE_ON_CONTENTION
        pid_t owner_id = this->owner_id;
        std::ostringstream msg;
        msg << "Data Race between [this] reader #" <<  caller_id
            << " and [other] writer #" << owner_id
            << " on lock " << this;
        if (context != NULL) {
            msg << std::endl << "In [this] context: " << context;
        }
        if (this->owner_context != NULL) {
            msg << std::endl << "In [other] context: " << this->owner_context;
        }
        throw std::runtime_error(msg.str());
        #else
        pid_t owner_id = this->owner_id;
        pthread_mutex_lock(&(CyLock::log_guard));
        std::cout
            << "Data Race between [this] reader #" <<  caller_id
            << " and [other] writer #" << owner_id
            << " on lock " << this << std::endl;
        if (context != NULL) {
            std::cout << "In [this] context: " << context << std::endl;
        }
        if (this->owner_context != NULL) {
            std::cout << "In [other] context: " << this->owner_context << std::endl;
        }
        pthread_mutex_unlock(&(CyLock::log_guard));
        #endif
    }

    while (this->write_count > 0) {
        pthread_cond_wait(&this->writer_has_left, &this->guard);
    }

    this->owner_id = this->readers_nb++ ? CyObject_MANY_OWNERS : caller_id;

    this->owner_context = context;

    pthread_mutex_unlock(&this->guard);
}

int CyLock::tryrlock() {
    pid_t caller_id = syscall(SYS_gettid);

    if (this->owner_id == caller_id) {
        ++this->readers_nb;
        return 0;
    }

    // we must lock here, because a trylock could fail also when another thread is currently read-locking or read-unlocking
    // but this means we might miss a writer arriving and leaving
    pthread_mutex_lock(&this->guard);

    if (this->write_count > 0) {
        pthread_mutex_unlock(&this->guard);
        return CyObject_CONTENDING_WRITER_FLAG;
    }

    this->owner_id = this->readers_nb++ ? CyObject_MANY_OWNERS : caller_id;

    pthread_mutex_unlock(&this->guard);

    return 0;
}

void CyLock::unrlock() {
    pthread_mutex_lock(&this->guard);

    if (--this->readers_nb == 0) {
        if (this->write_count == 0) {
            this->owner_id = CyObject_NO_OWNER;
        }

        // broadcast to wake up all the waiting writers
        pthread_cond_broadcast(&this->readers_have_left);
    }

    pthread_mutex_unlock(&this->guard);
}

void CyLock::wlock(const char *context) {
    pid_t caller_id = syscall(SYS_gettid);

    if (this->owner_id == caller_id) {
        if (this->write_count) {
            ++this->write_count;
            return;
        }
    }

    pthread_mutex_lock(&this->guard);

    pid_t owner_id = this->owner_id;

    if (owner_id != caller_id) {

        // Since we use a reader-preferring approach, we wait first for all readers to leave, and then all writers.
        // The other way around could result in several writers acquiring the lock.

        if (this->readers_nb > 0) {
            #if CyObject_RAISE_ON_CONTENTION
            pid_t owner_id = this->owner_id;
            std::ostringstream msg;
            msg << "Data Race between [this] writer #" <<  caller_id
                << " and [other] reader #" << owner_id
                << " on lock " << this;
            if (context != NULL) {
                msg << std::endl << "In [this] context: " << context;
            }
            if (this->owner_context != NULL) {
                msg << std::endl << "In [other] context: " << this->owner_context;
            }
            throw std::runtime_error(msg.str());
            #else
            std::cout
                << "Data Race between [this] writer #" <<  caller_id
                << " and [other] reader #" << owner_id
                << " on lock " << this << std::endl;
            if (context != NULL) {
                std::cout << "In [this] context: " << context << std::endl;
            }
            if (this->owner_context != NULL) {
                std::cout << "In [other] context: " << this->owner_context << std::endl;
            }
            #endif
        }

        while (this->readers_nb > 0) {
            pthread_cond_wait(&this->readers_have_left, &this->guard);
        }

        if (this->write_count > 0) {
            #if CyObject_RAISE_ON_CONTENTION
            pid_t owner_id = this->owner_id;
            std::ostringstream msg;
            msg << "Data Race between [this] writer #" <<  caller_id
                << " and [other] writer #" << owner_id
                << " on lock " << this;
            if (context != NULL) {
                msg << std::endl << "In [this] context: " << context;
            }
            if (this->owner_context != NULL) {
                msg << std::endl << "In [other] context: " << this->owner_context;
            }
            throw std::runtime_error(msg.str());
            #else
            pthread_mutex_lock(&(CyLock::log_guard));
            std::cout
                << "Data Race between [this] writer #" <<  caller_id
                << " and [other] writer #" << owner_id
                << " on lock " << this << std::endl;
            if (context != NULL) {
                std::cout << "In [this] context: " << context << std::endl;
            }
            if (this->owner_context != NULL) {
                std::cout << "In [other] context: " << this->owner_context << std::endl;
            }
            pthread_mutex_unlock(&(CyLock::log_guard));
            #endif
        }

        while (this->write_count > 0) {
            pthread_cond_wait(&this->writer_has_left, &this->guard);
        }

        this->owner_id = caller_id;
    }

    this->write_count = 1;

    this->owner_context = context;

    pthread_mutex_unlock(&this->guard);
}

int CyLock::trywlock() {
    pid_t caller_id = syscall(SYS_gettid);

    if (this->owner_id == caller_id) {
        if (this->write_count) {
            ++this->write_count;
            return 0;
        }
    }

    pthread_mutex_lock(&this->guard);

    if (this->owner_id != caller_id) {

        if (this->readers_nb > 0) {
            pthread_mutex_unlock(&this->guard);
            return CyObject_CONTENDING_READER_FLAG;
        }

        if (this->write_count > 0) {
            pthread_mutex_unlock(&this->guard);
            return CyObject_CONTENDING_WRITER_FLAG;
        }

        this->owner_id = caller_id;
    }

    this->write_count = 1;

    pthread_mutex_unlock(&this->guard);

    return 0;
}

void CyLock::unwlock() {
    pthread_mutex_lock(&this->guard);
    if (--this->write_count == 0) {
        if (this->readers_nb == 0) {
            this->owner_id = CyObject_NO_OWNER;
        }

        // broadcast to wake up all the waiting readers, + maybe one waiting writer
        // more efficient to count r waiting readers and w waiting writers and signal n + (w > 0) times
        pthread_cond_broadcast(&this->writer_has_left);
    }
    pthread_mutex_unlock(&this->guard);
}


/*
 * Atomic counter increment and decrement implementation based on
 * @source: https://www.boost.org/doc/libs/1_73_0/doc/html/atomic/usage_examples.html
 */ 
void CyObject::CyObject_INCREF()
{
    this->nogil_ob_refcnt.fetch_add(1, std::memory_order_relaxed);
}

int CyObject::CyObject_DECREF()
{
    if (this->nogil_ob_refcnt.fetch_sub(1, std::memory_order_release) == 1) {
        std::atomic_thread_fence(std::memory_order_acquire);
        delete this;
        return 1;
    }
    return 0;
}

int CyObject::CyObject_GETREF()
{
    return this->nogil_ob_refcnt;
}

void CyObject::CyObject_RLOCK(const char *context)
{
    this->ob_lock.rlock(context);
}

void CyObject::CyObject_WLOCK(const char *context)
{
    this->ob_lock.wlock(context);
}

int CyObject::CyObject_TRYRLOCK()
{
    return this->ob_lock.tryrlock();
}

int CyObject::CyObject_TRYWLOCK()
{
    return this->ob_lock.trywlock();
}
void CyObject::CyObject_UNRLOCK()
{
    this->ob_lock.unrlock();
}

void CyObject::CyObject_UNWLOCK()
{
    this->ob_lock.unwlock();
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
