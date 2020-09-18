cdef extern from * nogil:
    """
    template<typename urng_t, typename base_iterator_t, typename reference_t, reference_t (*getter_t)(base_iterator_t)>
    struct cy_iterator_t : base_iterator_t
    {
        using base = base_iterator_t;
        using reference = reference_t;

        urng_t urange = NULL;

        friend void swap(cy_iterator_t & first, cy_iterator_t & second)
        {
            using std::swap;
            swap(first.urange, second.urange);
            swap(static_cast<base&>(first), static_cast<base&>(second));
        }

        cy_iterator_t() = default;
        cy_iterator_t(cy_iterator_t const & rhs) : urange(rhs.urange)
        {
            if (urange != NULL)
            {
                urange->_active_iterators++;
            }
        }

        cy_iterator_t(cy_iterator_t && rhs) : cy_iterator_t()
        {
            swap(*this, rhs);
        }

        cy_iterator_t & operator=(cy_iterator_t rhs)
        {
            swap(*this, rhs);
            return *this;
        }

        cy_iterator_t & operator=(base_iterator_t rhs)
        {
            static_cast<base&>(*this) = rhs;
            if (urange != NULL) {
                urange->_active_iterators--;
                urange = NULL;
            }
            return *this;
        }

        ~cy_iterator_t()
        {
            if (urange != NULL) {
                urange->_active_iterators--;
                urange = NULL;
            }
        }

        cy_iterator_t(base const & b) : base{b} {}

        cy_iterator_t(base const & b, urng_t urange) : base{b}, urange{urange}
        {
            if (urange != NULL) {
                urange->_active_iterators++;
            }
        }

        cy_iterator_t operator++(int)
        {
            return static_cast<base&>(*this)++;
        }

        cy_iterator_t & operator++()
        {
            ++static_cast<base&>(*this);
            return (*this);
        }

        reference operator*() const
        {
            return getter_t(static_cast<base>(*this));
        }
    };
    """
