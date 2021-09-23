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
        #define CyObject_NO_OWNER -1
        #define CyObject_MANY_OWNERS -2

        #define CyObject_CONTENDING_WRITER_FLAG (1 << 0)
        #define CyObject_CONTENDING_READER_FLAG (1 << 1)

        #include <atomic>

        #include <pthread.h>
        #include <sys/types.h>
        #include <unistd.h>
        #include <sys/syscall.h>

        #include <vector>

        #include <sstream>
        #include <iostream>
        #include <stdexcept>

        #include <type_traits>

        class CyLock {
            protected:
                pthread_mutex_t guard;
                pthread_cond_t readers_have_left;
                pthread_cond_t writer_has_left;
                std::atomic<pid_t> owner_id;
                std::atomic_int readers_nb;
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
                ~CyLock() {
                    pthread_mutex_destroy(&this->guard);
                    pthread_cond_destroy(&this->readers_have_left);
                    pthread_cond_destroy(&this->writer_has_left);
                }
                void wlock(const char * context);
                void rlock(const char * context);
                void unwlock();
                void unrlock();
                int tryrlock();
                int trywlock();
        };

        struct CyPyObject {
            PyObject_HEAD
        };

        /*
         * Atomic counter increment and decrement implementation based on
         * @source: https://www.boost.org/doc/libs/1_73_0/doc/html/atomic/usage_examples.html
         */
        class CyObject : public CyPyObject {
            private:
                mutable std::atomic_int nogil_ob_refcnt;
                mutable CyLock ob_lock;

            public:
                mutable const CyObject * __next;
                mutable int __refcnt;
                CyObject(): nogil_ob_refcnt(1), __next(NULL), __refcnt(0) {}
                virtual ~CyObject() {}

                /* Object graph inspection methods */
                virtual int CyObject_iso() const {
                    return this->CyObject_GETREF() == 1;
                }
                virtual void CyObject_traverse_iso(void (*visit)(const CyObject *o, void *arg), void *arg) const {
                    return;
                }

                /* Locking methods */
                void CyObject_RLOCK(const char * context) const;
                void CyObject_WLOCK(const char * context) const;
                void CyObject_UNRLOCK() const;
                void CyObject_UNWLOCK() const;
                int CyObject_TRYRLOCK() const;
                int CyObject_TRYWLOCK() const;

                /* Reference counting methods */
                void CyObject_INCREF() const {
                    this->nogil_ob_refcnt.fetch_add(1, std::memory_order_relaxed);
                }
                int CyObject_DECREF() const {
                    if (this->nogil_ob_refcnt.fetch_sub(1, std::memory_order_release) == 1) {
                        std::atomic_thread_fence(std::memory_order_acquire);
                        delete this;
                        return 1;
                    }
                    return 0;
                }
                int CyObject_GETREF() const {
                    return this->nogil_ob_refcnt.load(std::memory_order_relaxed);
                }
        };

        template <typename T, typename = void>
        struct Cy_has_equality : std::false_type {};

        template <typename T>
        struct Cy_has_equality<T, typename std::enable_if<std::is_convertible<decltype( std::declval<T>().operator==(std::declval<T*>()) ), bool>::value>::type> : std::true_type {};

        template <typename T, typename = void>
        struct Cy_has_hash : std::false_type {};

        template <typename T>
        struct Cy_has_hash<T, typename std::enable_if<std::is_convertible<decltype( std::declval<T>().__hash__() ), std::size_t>::value>::type> : std::true_type {};

        template <typename T, bool iso = false>
        struct Cy_Ref_impl {
            T* uobj = nullptr;

            constexpr Cy_Ref_impl() noexcept = default;

            constexpr Cy_Ref_impl(T* const& uobj) noexcept : uobj(uobj) {}

            constexpr Cy_Ref_impl(T* && uobj) noexcept : uobj(uobj) {}

            Cy_Ref_impl(const Cy_Ref_impl& rhs) : uobj(rhs.uobj) {
                if (uobj != nullptr) {
                    uobj->CyObject_INCREF();
                }
            }

            template<typename U, bool _iso, typename std::enable_if<std::is_convertible<U*, T*>::value, int>::type = 0>
            Cy_Ref_impl(const Cy_Ref_impl<U, _iso>& rhs) : uobj(rhs.uobj) {
                if (uobj != nullptr) {
                    uobj->CyObject_INCREF();
                }
            }

            Cy_Ref_impl(Cy_Ref_impl&& rhs) noexcept : uobj(rhs.uobj) {
                rhs.uobj = nullptr;
            }

            template<typename U, bool _iso, typename std::enable_if<std::is_convertible<U*, T*>::value, int>::type = 0>
            Cy_Ref_impl(Cy_Ref_impl<U, _iso>&& rhs) noexcept : uobj(rhs.uobj) {
                rhs.uobj = nullptr;
            }

            Cy_Ref_impl& operator=(Cy_Ref_impl rhs) noexcept {
                std::swap(uobj, rhs.uobj);
                return *this;
            }

            ~Cy_Ref_impl() {
                if (uobj != nullptr) {
                    uobj->CyObject_DECREF();
                    uobj = nullptr;
                }
            }

            constexpr T& operator*() const noexcept{
                return *uobj;
            }

            constexpr T* operator->() const noexcept {
                return uobj;
            }

            explicit operator bool() const noexcept {
                return uobj;
            }

            operator T*() const& {
                if (uobj != nullptr) {
                    uobj->CyObject_INCREF();
                }
                return uobj;
            }

            operator T*() && {
                T* obj = uobj;
                uobj = nullptr;
                return obj;
            }

            template <typename U, bool _iso>
            bool operator==(const Cy_Ref_impl<U, _iso>& rhs) const noexcept {
                return uobj == rhs.uobj;
            }

            template <typename U>
            bool operator==(U* rhs) const noexcept {
                return uobj == rhs;
            }

            template <typename U>
            friend bool operator==(U* lhs, const Cy_Ref_impl<T, iso>& rhs) noexcept {
                return lhs == rhs.uobj;
            }

            bool operator==(std::nullptr_t) const noexcept {
                return uobj == nullptr;
            }

            friend bool operator==(std::nullptr_t, const Cy_Ref_impl<T, iso>& rhs) noexcept {
                return rhs.uobj == nullptr;
            }

            template <typename U, bool _iso>
            bool operator!=(const Cy_Ref_impl<U, _iso>& rhs) const noexcept {
                return uobj != rhs.uobj;
            }

            template <typename U>
            bool operator!=(U* rhs) const noexcept {
                return uobj != rhs;
            }

            template <typename U>
            friend bool operator!=(U* lhs, const Cy_Ref_impl<T, iso>& rhs) noexcept {
                return lhs != rhs.uobj;
            }

            bool operator!=(std::nullptr_t) const noexcept {
                return uobj != nullptr;
            }

            friend bool operator!=(std::nullptr_t, const Cy_Ref_impl<T, iso>& rhs) noexcept {
                return rhs.uobj != nullptr;
            }
        };

        namespace std {
        template <typename T, bool iso>
        struct hash<Cy_Ref_impl<T, iso>> {
            template <typename U = T, typename std::enable_if<!Cy_has_hash<U>::value, int>::type = 0>
            size_t operator()(const Cy_Ref_impl<T, iso>& ref) const {
                static_assert(!Cy_has_equality<U>::value, "Cypclasses that define __eq__ must also define __hash__ to be hashable");
                return std::hash<T*>()(ref.uobj);
            }
            template <typename U = T, typename std::enable_if<Cy_has_hash<U>::value, int>::type = 0>
            size_t operator()(const Cy_Ref_impl<T, iso>& ref) const {
                static_assert(Cy_has_equality<U>::value, "Cypclasses that define __hash__ must also define __eq__ to be hashable");
                return ref.uobj->__hash__();
            }
        };

        template <typename T, bool iso>
        struct equal_to<Cy_Ref_impl<T, iso>> {
            template <typename U = T, typename std::enable_if<!Cy_has_equality<U>::value, int>::type = 0>
            bool operator()(const Cy_Ref_impl<T, iso>& lhs, const Cy_Ref_impl<T, iso>& rhs) const {
                return lhs.uobj == rhs.uobj;
            }
            template <typename U = T, typename std::enable_if<Cy_has_equality<U>::value, int>::type = 0>
            bool operator()(const Cy_Ref_impl<T, iso>& lhs, const Cy_Ref_impl<T, iso>& rhs) const {
                Cy_INCREF(rhs.uobj);
                return lhs.uobj->operator==(rhs.uobj);
            }
        };
        }

        template <typename T, bool iso = false>
        struct Cy_Ref_t {
            using type = Cy_Ref_impl<T, iso>;
        };

        template <typename T>
        struct Cy_Ref_t<Cy_Ref_impl<T, false>> {
            using type = Cy_Ref_impl<T, false>;
        };

        template <typename T>
        struct Cy_Ref_t<Cy_Ref_impl<T, true>> {
            using type = Cy_Ref_impl<T, true>;
        };

        template <typename T, bool iso = false>
        using Cy_Ref = typename Cy_Ref_t<T, iso>::type;

        template <typename T>
        struct Cy_Raw_t {
            using type = T;
        };

        template <typename T>
        struct Cy_Raw_t<Cy_Ref_impl<T, false>> {
            using type = T*;
        };

        template <typename T>
        struct Cy_Raw_t<Cy_Ref_impl<T, true>> {
            using type = T*;
        };

        template <typename T>
        using Cy_Raw = typename Cy_Raw_t<T>::type;

        class Cy_rlock_guard {
            const CyObject* o;
            public:
                Cy_rlock_guard(const CyObject* o, const char * context) : o(o) {
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
                        this->o->CyObject_DECREF();
                    }
                    else {
                        fprintf(stderr, "ERROR: trying to unrlock NULL !\n");
                    }
                }
        };

        class Cy_wlock_guard {
            const CyObject* o;
            public:
                Cy_wlock_guard(const CyObject* o, const char * context) : o(o) {
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
                        this->o->CyObject_DECREF();
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
            virtual void insertActivity() = 0;
            virtual void removeActivity() = 0;
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
            virtual ~ActhonActivableClass();
        };


        template <typename T>
        static inline void Cy_DECREF(T &ob) {
            if(ob->CyObject_DECREF())
                ob = NULL;
        }

        template <typename T>
        static inline void Cy_XDECREF(T &ob) {
            if (ob != NULL) {
                if(ob->CyObject_DECREF())
                    ob = NULL;
            }
        }

        template <typename T>
        static inline void Cy_INCREF(T ob) {
            if (ob != NULL)
                ob->CyObject_INCREF();
        }

        static inline int _Cy_GETREF(const CyObject *ob) {
            return ob->CyObject_GETREF();
        }

        static inline int Cy_GETREF(const CyObject *ob) {
            int refcnt = ob->CyObject_GETREF();
            ob->CyObject_DECREF();
            return refcnt;
        }

        static inline void _Cy_RLOCK(const CyObject *ob, const char *context) {
            if (ob != NULL) {
                ob->CyObject_RLOCK(context);
            }
            else {
                fprintf(stderr, "ERROR: trying to read lock NULL !\n");
            }
        }

        static inline void _Cy_WLOCK(const CyObject *ob, const char *context) {
            if (ob != NULL) {
                ob->CyObject_WLOCK(context);
            }
            else {
                fprintf(stderr, "ERROR: trying to write lock NULL !\n");
            }
        }

        static inline void _Cy_UNRLOCK(const CyObject *ob) {
            if (ob != NULL) {
                ob->CyObject_UNRLOCK();
            }
            else {
                fprintf(stderr, "ERROR: trying to unrlock NULL !\n");
            }
        }

        static inline void _Cy_UNWLOCK(const CyObject *ob) {
            if (ob != NULL) {
                ob->CyObject_UNWLOCK();
            }
            else {
                fprintf(stderr, "ERROR: trying to unwlock NULL !\n");
            }
        }

        static inline int _Cy_TRYRLOCK(const CyObject *ob) {
            return ob->CyObject_TRYRLOCK();
        }

        static inline int _Cy_TRYWLOCK(const CyObject *ob) {
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
            bool result = dynamic_cast<const typename std::remove_pointer<T>::type *>(ob) != NULL;
            Cy_DECREF(ob);
            return result;
        }

        /*
            * Activate a passive Cyobject.
            */
        template <typename T>
        static inline T * activate(T * ob) {
            static_assert(std::is_convertible<T *, ActhonActivableClass *>::value, "wrong type for activate");
            return ob;
        }

        /*
            * Traverse template fields.
            */
        template <typename T>
        struct Cy_traverse_iso : std::false_type {};

        template <typename T>
        struct Cy_traverse_iso<Cy_Ref_impl<T, false>> : std::true_type {};

        template <typename T, typename std::enable_if<!Cy_traverse_iso<T>::value, int>::type = 0>
        static inline void __Pyx_CyObject_visit_template(void (*visit)(const CyObject *o, void*arg), const T& o, void *arg) {
        }

        template <typename T, typename std::enable_if<Cy_traverse_iso<T>::value, int>::type = 0>
        static inline void __Pyx_CyObject_visit_template(void (*visit)(const CyObject *o, void*arg), const T& o, void *arg) {
            visit(o.uobj, arg);
        }

        /*
            * Traverse generic containers.
            */
        template<typename... Ts> struct Cy_make_void { typedef void type;};
        template<typename... Ts> using Cy_void_t = typename Cy_make_void<Ts...>::type; // C++11 compatible version of std::void_t

        template <typename T, typename = void>
        struct Cy_is_iterable : std::false_type {};

        template <typename T>
        struct Cy_is_iterable<
            T, Cy_void_t<
                decltype(std::begin(std::declval<T>()) != std::end(std::declval<T>())),
                decltype(++std::begin(std::declval<T>())),
                decltype(*std::begin(std::declval<T>()))
            >
        > : std::true_type {};

        template <typename T>
        struct Cy_is_pair: std::false_type {};

        template <typename ... Ts>
        struct Cy_is_pair<std::pair<Ts...>> : std::true_type {};

        template <typename T, typename std::enable_if<Cy_traverse_iso<T>::value, int>::type = 0>
        static inline void __Pyx_CyObject_visit_generic(void (*visit)(const CyObject *o, void*arg), const T& o, void *arg) {
            visit(o.uobj, arg);
        }

        template <typename T, typename std::enable_if<Cy_is_iterable<T>::value, int>::type = 0>
        static inline void __Pyx_CyObject_visit_generic(void (*visit)(const CyObject *o, void*arg), const T& o, void *arg) {
            for (auto& e : o) {
                __Pyx_CyObject_visit_generic(visit, e, arg);
            }
        }

        template <typename T, typename std::enable_if<Cy_is_pair<T>::value, int>::type = 0>
        static inline void __Pyx_CyObject_visit_generic(void (*visit)(const CyObject *o, void*arg), const T& o, void *arg) {
            __Pyx_CyObject_visit_generic(visit, o.first, arg);
            __Pyx_CyObject_visit_generic(visit, o.second, arg);
        }

        template <typename T, typename std::enable_if<
            !Cy_is_pair<T>::value && !Cy_is_iterable<T>::value && !Cy_traverse_iso<T>::value, int
        >::type = 0>
        static inline void __Pyx_CyObject_visit_generic(void (*visit)(const CyObject *o, void*arg), const T& o, void *arg) {}

        /*
            * Visit callback to collect reachable fields.
            */
        static void __Pyx_CyObject_visit_collect(const CyObject *ob, void *arg) {
            if (!ob)
                return;
            if (ob->__refcnt)
                return;
            ob->__refcnt = ob->CyObject_GETREF();
            const CyObject *head = reinterpret_cast<CyObject *>(arg);
            const CyObject *tmp = head->__next;
            ob->__next = tmp;
            head->__next = ob;
        }

        /*
            * Visit callback to decref reachable fields.
            */
        static void __Pyx_CyObject_visit_decref(const CyObject *ob, void *arg) {
            (void) arg;
            if (!ob)
                return;
            ob->__refcnt -= 1;
        }

        /*
            * Check if a CyObject is owning.
            */
        static inline int __Pyx_CyObject_owning(const CyObject *root) {
            const CyObject *current;
            bool owning = true;
            int owners;
            /* Mark the root as already visited */
            root->__refcnt = root->CyObject_GETREF();
            /* Collect the reachable objects */
            for(current = root; current != NULL; current = current->__next) {
                current->CyObject_traverse_iso(__Pyx_CyObject_visit_collect, (void*)current);
            }
            /* Decref the reachable objects */
            for(current = root; current != NULL; current = current->__next) {
                current->CyObject_traverse_iso(__Pyx_CyObject_visit_decref, (void*)current);
            }
            /* Search for externally reachable object */
            for(current = root->__next; current != NULL; current = current->__next) {
                if (current->__refcnt)
                    owning = false;
            }
            /* Count external potential owners */
            owners = root->__refcnt;
            /* Cleanup */
            for(current = root; current != NULL;) {
                current->__refcnt = 0;
                const CyObject *next = current->__next;
                current->__next = NULL;
                current = next;
            }
            return owning ? owners : 0;
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

        while (this->readers_nb > 0) {
            pthread_cond_wait(&this->readers_have_left, &this->guard);
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

void CyObject::CyObject_RLOCK(const char *context) const
{
    this->ob_lock.rlock(context);
}

void CyObject::CyObject_WLOCK(const char *context) const
{
    this->ob_lock.wlock(context);
}

int CyObject::CyObject_TRYRLOCK() const
{
    return this->ob_lock.tryrlock();
}

int CyObject::CyObject_TRYWLOCK() const
{
    return this->ob_lock.trywlock();
}
void CyObject::CyObject_UNRLOCK() const
{
    this->ob_lock.unrlock();
}

void CyObject::CyObject_UNWLOCK() const
{
    this->ob_lock.unwlock();
}


ActhonMessageInterface::ActhonMessageInterface(ActhonSyncInterface* sync_method,
    ActhonResultInterface* result_object) : _sync_method(sync_method), _result(result_object)
{
    Cy_INCREF(this->_result);
}

ActhonMessageInterface::~ActhonMessageInterface()
{
    Cy_XDECREF(this->_sync_method);
    Cy_XDECREF(this->_result);
}

ActhonActivableClass::~ActhonActivableClass()
{
    Cy_XDECREF(this->_active_queue_class);
}
